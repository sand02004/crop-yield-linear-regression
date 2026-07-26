# Crop Yield Prediction — African Agriculture

## Mission
## Mission
Agricultural planning across Africa is often hampered by unpredictable crop yields, making it
hard for farmers and policymakers to plan for food security. This project predicts crop yield
(hg/ha) for African countries using rainfall, pesticide use, temperature, crop type, and year,
helping stakeholders make more informed agricultural decisions.

## Dataset
Source: [Crop Yield Prediction Dataset](https://www.kaggle.com/datasets/patelris/crop-yield-prediction-dataset) (Kaggle).
The dataset was filtered to 31 African countries and 10 crop types (5,362 rows after cleaning),
containing yield, rainfall, pesticide use, and average temperature data from 1990–2013.

## API
- **Public API base URL:** https://crop-yield-linear-regression.onrender.com
- **Swagger UI (interactive docs):** https://crop-yield-linear-regression.onrender.com/docs

> Note: the API is hosted on Render's free tier, which spins down after inactivity. The first
> request after a period of inactivity may take 30-60 seconds to respond while the server wakes up.

## Project Structure
```
summative/
├── linear_regression/
│   └── multivariate.ipynb     # EDA, feature engineering, model training & comparison
├── API/
│   ├── prediction.py          # FastAPI app (predict + retrain endpoints)
│   ├── requirements.txt
│   ├── best_model.pkl
│   ├── scaler.pkl
│   └── feature_columns.pkl
└── FlutterApp/                # Mobile app (single prediction screen)
```

## Running the Mobile App
1. Ensure you have Flutter installed ([flutter.dev/get-started](https://flutter.dev/get-started)).
2. Clone this repository and navigate to `summative/FlutterApp`.
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Run the app on a connected device or emulator:
   ```
   flutter run
   ```
5. The app is pre-configured to call the live API at the URL listed above — no setup needed
   to make predictions.

## Running the API Locally (optional)
```
cd summative/API
pip install -r requirements.txt
uvicorn prediction:app --reload
```
Then visit `http://127.0.0.1:8000/docs` for the local Swagger UI.

## Video Demo
(https://youtu.be/NTSNRsJXI74)