import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// IMPORTANT: change this once your API is deployed on Render.
// For now, using the Android emulator alias for localhost (10.0.2.2),
// since 127.0.0.1 inside an emulator refers to the emulator itself, not
// your PC. If testing on a real device, use your PC's local network IP
// instead (e.g. http://192.168.x.x:8001).
// ---------------------------------------------------------------------------
const String baseUrl = "http://10.0.2.2:8001";
// const String baseUrl = "https://your-app-name.onrender.com"; // <-- switch to this after deploying

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
  final _areaController = TextEditingController();
  final _itemController = TextEditingController();
  final _yearController = TextEditingController();
  final _rainfallController = TextEditingController();
  final _pesticidesController = TextEditingController();
  final _tempController = TextEditingController();

  String _resultText = "";
  bool _isLoading = false;
  bool _isError = false;

  Future<void> _predictYield() async {
    // Basic check: make sure nothing is empty before calling the API
    if (_areaController.text.isEmpty ||
        _itemController.text.isEmpty ||
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
          "area": _areaController.text.trim(),
          "item": _itemController.text.trim(),
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
    _areaController.dispose();
    _itemController.dispose();
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

              _buildTextField(_areaController, "Country (e.g. Kenya)", isNumber: false),
              const SizedBox(height: 12),
              _buildTextField(_itemController, "Crop (e.g. Maize)", isNumber: false),
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