import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl;

  ApiService({required this.baseUrl});

  void updateBaseUrl(String newUrl) {
    // Remove slash final se existir
    baseUrl = newUrl.endsWith('/') ? newUrl.substring(0, newUrl.length - 1) : newUrl;
  }

  Future<bool> move(int steps, {int? speed}) async {
    try {
      String url = '$baseUrl/move?steps=$steps';
      if (speed != null) url += '&speed=$speed';
      final response = await http.post(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('Erro no move: $e');
      return false;
    }
  }

  Future<String> getStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      if (response.statusCode == 200) {
        // Tenta interpretar como JSON
        try {
          final data = jsonDecode(response.body);
          return data['status']?.toString().toLowerCase() ?? 'unknown';
        } catch (_) {
          // Fallback para texto simples
          return response.body.trim().toLowerCase();
        }
      }
      return 'error';
    } catch (e) {
      print('Erro no getStatus: $e');
      return 'error';
    }
  }

  // Comandos manuais
  Future<bool> startContinuousSpin({int? speed}) async {
    try {
      String url = '$baseUrl/spin';
      if (speed != null) url += '?speed=$speed';
      // Usando uma rota de spin contínuo, se não existir, usa move com passos altos
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 404) {
        return move(999999, speed: speed);
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Erro no giro contínuo: $e');
      return false;
    }
  }

  Future<bool> stopSpin() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/stop'));
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao parar motor: $e');
      return false;
    }
  }

  Future<bool> setSpeed(int speed) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/speed?value=$speed'));
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao alterar velocidade: $e');
      return false;
    }
  }
}
