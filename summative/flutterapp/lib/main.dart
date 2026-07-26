import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "https://crop-yield-linear-regression.onrender.com";


const List<String> africanCountries = [
  "Algeria", "Angola", "Botswana", "Burkina Faso", "Burundi", "Cameroon",
  "Central African Republic", "Egypt", "Eritrea", "Ghana", "Guinea",
  "Kenya", "Lesotho", "Libya", "Madagascar", "Malawi", "Mali",
  "Mauritania", "Mauritius", "Morocco", "Mozambique", "Namibia",
  "Niger", "Rwanda", "Senegal", "South Africa", "Sudan", "Tunisia",
  "Uganda", "Zambia", "Zimbabwe",
];

// The 10 crop types present in the training dataset.
const List<String> cropTypes = [
  "Cassava", "Maize", "Plantains and others", "Potatoes", "Rice, paddy",
  "Sorghum", "Soybeans", "Sweet potatoes", "Wheat", "Yams",
];

void main() {
  runApp(const CropYieldApp());
}

class CropYieldApp extends StatelessWidget {
  const CropYieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Yield Predictor',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  String? _selectedArea;
  String? _selectedItem;

  final _yearController = TextEditingController();
  final _rainfallController = TextEditingController();
  final _pesticidesController = TextEditingController();
  final _tempController = TextEditingController();

  String _resultText = "";
  bool _isLoading = false;
  bool _isError = false;

  Future<void> _predictYield() async {
    // Basic check: make sure nothing is empty before calling the API
    if (_selectedArea == null ||
        _selectedItem == null ||
        _yearController.text.isEmpty ||
        _rainfallController.text.isEmpty ||
        _pesticidesController.text.isEmpty ||
        _tempController.text.isEmpty) {
      setState(() {
        _isError = true;
        _resultText = "Please fill in all fields before predicting.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isError = false;
      _resultText = "";
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/predict"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "area": _selectedArea,
          "item": _selectedItem,
          "year": int.parse(_yearController.text.trim()),
          "average_rain_fall_mm_per_year": double.parse(_rainfallController.text.trim()),
          "pesticides_tonnes": double.parse(_pesticidesController.text.trim()),
          "avg_temp": double.parse(_tempController.text.trim()),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isError = false;
          _resultText =
              "Predicted Yield: ${data['predicted_yield_hg_ha']} hg/ha\nfor ${data['item']} in ${data['area']}";
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _isError = true;
          _resultText = "Error: ${data['detail']}";
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _resultText = "Could not reach the API. Check your connection or the server URL.\n($e)";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _rainfallController.dispose();
    _pesticidesController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Yield Predictor'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                "Enter the details below to predict crop yield (hg/ha).",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Country dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedArea,
                decoration: const InputDecoration(
                  labelText: "Country",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: africanCountries
                    .map((country) => DropdownMenuItem(value: country, child: Text(country)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedArea = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Crop dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedItem,
                decoration: const InputDecoration(
                  labelText: "Crop",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: cropTypes
                    .map((crop) => DropdownMenuItem(value: crop, child: Text(crop)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedItem = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              _buildTextField(_yearController, "Year (e.g. 2013)", isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_rainfallController, "Average Rainfall (mm/year)", isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_pesticidesController, "Pesticides (tonnes)", isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_tempController, "Average Temperature (°C)", isNumber: true),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _predictYield,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Predict", style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 24),

              if (_resultText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isError ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    _resultText,
                    style: TextStyle(
                      fontSize: 15,
                      color: _isError ? Colors.red.shade800 : Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {required bool isNumber}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}