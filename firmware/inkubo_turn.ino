#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266mDNS.h>
#include <Stepper.h>

// Configuração do Motor de Passo (28BYJ-48)
const int stepsPerRevolution = 2048;

// Ordem corrigida para evitar vibração (IN1, IN3, IN2, IN4)
// Pinos físicos no NodeMCU: D1 (5), D5 (14), D2 (4), D6 (12)
Stepper myStepper(stepsPerRevolution, 5, 14, 4, 12);

ESP8266WebServer server(80);

// Variáveis de controle de estado do motor (Não-bloqueante)
int stepsRemaining = 0;
int motorDirection = 1; 
unsigned long lastStepTime = 0;
int stepDelayMicros = 2000; // Velocidade padrão inicial

// Função auxiliar para enviar respostas padronizadas em JSON
void sendJSONResponse(int statusCode, String statusValue, String message) {
  String json = "{\"status\":\"" + statusValue + "\",\"message\":\"" + message + "\"}";
  server.send(statusCode, "application/json", json);
}

// Verifica se o Flutter enviou o parâmetro de velocidade na URL (?speed=X)
void updateSpeedFromRequest() {
  if (server.hasArg("speed")) {
    int speedValue = server.arg("speed").toInt();
    
    // Garante que o valor enviado pelo slider esteja entre 1 e 10
    speedValue = constrain(speedValue, 1, 10);
    
    // Mapeia: 1 (Mais Lento -> 6000us) até 10 (Mais Rápido -> 2800us)
    stepDelayMicros = map(speedValue, 1, 10, 6000, 2800);
  }
}

// Rota GET /status
void handleStatus() {
  if (stepsRemaining > 0) {
    sendJSONResponse(200, "moving", "O motor esta girando.");
  } else {
    sendJSONResponse(200, "idle", "O motor esta parado.");
  }
}

// Rota POST /move?steps=X&speed=Y
void handleMove() {
  updateSpeedFromRequest(); // Atualiza a velocidade se enviada
  
  if (server.hasArg("steps")) {
    int steps = server.arg("steps").toInt();
    if (steps != 0) {
      motorDirection = (steps > 0) ? 1 : -1;
      stepsRemaining = abs(steps);
      sendJSONResponse(200, "ack", "Movimento aceito.");
      return;
    }
  }
  sendJSONResponse(400, "error", "Parametro 'steps' invalido ou ausente.");
}

// Rota POST /continuous?speed=X
void handleContinuous() {
  updateSpeedFromRequest(); // Atualiza a velocidade se enviada
  
  stepsRemaining = 999999; // Define um valor alto para simular giro continuo
  motorDirection = 1;
  sendJSONResponse(200, "ack", "Giro continuo iniciado.");
}

// Rota POST /stop
void handleStop() {
  stepsRemaining = 0;
  
  // Força o desligamento imediato das bobinas para economizar energia e não esquentar
  digitalWrite(5, LOW); 
  digitalWrite(14, LOW); 
  digitalWrite(4, LOW); 
  digitalWrite(12, LOW);
  
  sendJSONResponse(200, "idle", "Motor parado emergencialmente.");
}

void setup() {
  Serial.begin(115200);
  
  // -------------------------------------------------------------------------
  // ATENÇÃO: Substitua com os dados da rede Wi-Fi da sua casa
  // -------------------------------------------------------------------------
  WiFi.begin("********", "********");
  
  Serial.print("Conectando ao Wi-Fi da Inkubo3d");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nConectado com sucesso!");
  Serial.print("IP local da base: ");
  Serial.println(WiFi.localIP()); 

  // Inicia o mDNS para responder por http://inkuboturn.local
  if (MDNS.begin("inkuboturn")) {
    Serial.println("mDNS configurado! Disponivel em: http://inkuboturn.local");
  }

  // Definição das Rotas da API do Inkubo Turn
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/move", HTTP_POST, handleMove);       
  server.on("/continuous", HTTP_POST, handleContinuous);
  server.on("/stop", HTTP_POST, handleStop);

  server.begin();
  Serial.println("Servidor API HTTP pronto para receber comandos.");
}

void loop() {
  MDNS.update();         // Mantém o serviço de nome mDNS ativo
  server.handleClient(); // Processa as requisições vindas do app em Flutter

  // Máquina de estados do motor (Gira passo a passo sem travar a CPU)
  if (stepsRemaining > 0) {
    unsigned long currentMicros = micros();
    
    // Só dá o próximo passo quando o tempo configurado (velocidade) passar
    if (currentMicros - lastStepTime >= (unsigned long)stepDelayMicros) {
      myStepper.step(motorDirection);
      stepsRemaining--;
      lastStepTime = currentMicros;
    }
  } else if (stepsRemaining == 0) {
    // Garante que o motor fique totalmente frio e relaxado quando parado
    digitalWrite(5, LOW); 
    digitalWrite(14, LOW); 
    digitalWrite(4, LOW); 
    digitalWrite(12, LOW);
  }
}