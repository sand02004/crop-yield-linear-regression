"""
Crop Yield Prediction API
Wraps a trained Random Forest model to predict crop yield (hg/ha)
based on country, crop type, year, rainfall, pesticide use, and temperature.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import pandas as pd
import joblib
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

model = joblib.load(os.path.join(BASE_DIR, "best_model.pkl"))
scaler = joblib.load(os.path.join(BASE_DIR, "scaler.pkl"))
feature_columns = joblib.load(os.path.join(BASE_DIR, "feature_columns.pkl"))

NUMERIC_COLS = ["Year", "average_rain_fall_mm_per_year", "pesticides_tonnes", "avg_temp"]

VALID_AREAS = sorted({col.replace("Area_", "") for col in feature_columns if col.startswith("Area_")})
VALID_ITEMS = sorted({col.replace("Item_", "") for col in feature_columns if col.startswith("Item_")})

BASELINE_AREA = "Algeria"   # alphabetically first Area (African subset), dropped during one-hot encoding
BASELINE_ITEM = "Cassava"   # alphabetically first Item, dropped during one-hot encoding

VALID_AREAS.append(BASELINE_AREA)
VALID_ITEMS.append(BASELINE_ITEM)
VALID_AREAS.sort()
VALID_ITEMS.sort()

app = FastAPI(
    title="Crop Yield Prediction API",
    description="Predicts crop yield (hg/ha) from country, crop type, year, rainfall, pesticide use, and temperature.",
    version="1.0.0",
)
origins = [
    "https://crop-yield-linear-regression.onrender.com",
    "http://localhost:3000",
    "http://localhost:8080",
    "http://localhost:5000",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5000",
    "http://127.0.0.1:8000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class YieldPredictionRequest(BaseModel):
    area: str = Field(..., description="Country name, e.g. 'Kenya'")
    item: str = Field(..., description="Crop type, e.g. 'Maize'")
    year: int = Field(..., ge=1990, le=2035, description="Year of cultivation")
    average_rain_fall_mm_per_year: float = Field(
        ..., ge=0, le=5000, description="Average annual rainfall in mm"
    )
    pesticides_tonnes: float = Field(
        ..., ge=0, le=400000, description="Pesticide use in tonnes"
    )
    avg_temp: float = Field(
        ..., ge=-10, le=45, description="Average temperature in Celsius"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "area": "Kenya",
                "item": "Maize",
                "year": 2013,
                "average_rain_fall_mm_per_year": 1200.0,
                "pesticides_tonnes": 500.0,
                "avg_temp": 22.5,
            }
        }


class YieldPredictionResponse(BaseModel):
    predicted_yield_hg_ha: float
    area: str
    item: str


class RetrainResponse(BaseModel):
    message: str
    rows_used: int
    new_r2_score: float

def build_input_row(area: str, item: str, year: int, rainfall: float,
                     pesticides: float, avg_temp: float) -> pd.DataFrame:
    row = {
        "Year": year,
        "average_rain_fall_mm_per_year": rainfall,
        "pesticides_tonnes": pesticides,
        "avg_temp": avg_temp,
    }
    for col in feature_columns:
        if col.startswith("Area_") or col.startswith("Item_"):
            row[col] = 0

    input_df = pd.DataFrame([row])

    area_col = f"Area_{area}"
    item_col = f"Item_{item}"
    if area_col in input_df.columns:
        input_df[area_col] = 1
    if item_col in input_df.columns:
        input_df[item_col] = 1

    input_df = input_df.reindex(columns=feature_columns, fill_value=0)
    input_df[NUMERIC_COLS] = scaler.transform(input_df[NUMERIC_COLS])
    return input_df

@app.get("/")
def root():
    return {"message": "Crop Yield Prediction API is running. Visit /docs for Swagger UI."}


@app.post("/predict", response_model=YieldPredictionResponse)
def predict(request: YieldPredictionRequest):
    if request.area not in VALID_AREAS:
        raise HTTPException(
            status_code=400,
            detail=f"'{request.area}' is not a recognized country. Must be one of the {len(VALID_AREAS)} countries the model was trained on.",
        )
    if request.item not in VALID_ITEMS:
        raise HTTPException(
            status_code=400,
            detail=f"'{request.item}' is not a recognized crop. Valid options: {VALID_ITEMS}",
        )

    input_df = build_input_row(
        request.area, request.item, request.year,
        request.average_rain_fall_mm_per_year,
        request.pesticides_tonnes, request.avg_temp,
    )
    prediction = model.predict(input_df)[0]

    return YieldPredictionResponse(
        predicted_yield_hg_ha=round(float(prediction), 2),
        area=request.area,
        item=request.item,
    )


@app.post("/retrain", response_model=RetrainResponse)
def retrain(file_url: str = None):
    """
    Triggers retraining of the model using newly uploaded data.

    For this project, retraining is triggered manually via this endpoint by
    providing a CSV (same schema as yield_df.csv) already placed at
    'new_data.csv' in the API folder, OR by extending this endpoint to accept
    a file upload directly (see FastAPI's UploadFile for that variant).
    """
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.preprocessing import StandardScaler
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import r2_score

    data_path = os.path.join(BASE_DIR, "new_data.csv")
    if not os.path.exists(data_path):
        raise HTTPException(
            status_code=400,
            detail="No new_data.csv found in the API directory. Upload new data there before calling /retrain.",
        )

    new_df = pd.read_csv(data_path)
    if "Unnamed: 0" in new_df.columns:
        new_df = new_df.drop(columns=["Unnamed: 0"])

    df_encoded = pd.get_dummies(new_df, columns=["Area", "Item"], drop_first=True)
    df_encoded = df_encoded.reindex(columns=feature_columns + ["hg/ha_yield"], fill_value=0)

    X_new = df_encoded.drop(columns=["hg/ha_yield"])
    y_new = df_encoded["hg/ha_yield"]

    X_train, X_test, y_train, y_test = train_test_split(X_new, y_new, test_size=0.2, random_state=42)

    new_scaler = StandardScaler()
    X_train[NUMERIC_COLS] = new_scaler.fit_transform(X_train[NUMERIC_COLS])
    X_test[NUMERIC_COLS] = new_scaler.transform(X_test[NUMERIC_COLS])

    new_model = RandomForestRegressor(n_estimators=100, max_depth=18, random_state=42, n_jobs=-1)
    new_model.fit(X_train, y_train)

    new_r2 = r2_score(y_test, new_model.predict(X_test))

    joblib.dump(new_model, os.path.join(BASE_DIR, "best_model.pkl"), compress=3)
    joblib.dump(new_scaler, os.path.join(BASE_DIR, "scaler.pkl"))

    global model, scaler
    model = new_model
    scaler = new_scaler

    return RetrainResponse(
        message="Model retrained successfully using new_data.csv",
        rows_used=len(new_df),
        new_r2_score=round(float(new_r2), 4),
    )