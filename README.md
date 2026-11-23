# Controle Remoto Smart TV Universal (Flutter)

Aplicativo para controle de Smart TVs (Samsung Tizen, Roku TV, LG webOS e Universal) via rede local Wi-Fi, com interface em Português do Brasil inspirada no design original das principais marcas e construída com estética neumórfica 3D (Neu3D).

---

## 📱 Recursos
- **Suporte Multi-Marcas & Protocolos Nativos**:
  - **Samsung**: WebSocket seguro (`wss://IP:8002/api/v2/channels/...`) com certificado autoassinado e gerenciamento de token (`ms.channel.connect`).
  - **Roku TV**: Comunicação nativa via External Control Protocol (ECP HTTP na porta `8060`) para modelos TCL Roku, AOC, Philco, Semp e Roku Express.
  - **LG webOS**: Comunicação via WebSocket na porta `3000` (protocolo SSAP).
- **Descoberta Automática de TVs**: Varredura inteligente de sub-rede /24 com checagem assíncrona nas portas `8002` (Samsung), `8060` (Roku) e `3000` (LG), com suporte a SSDP multicast.
- **Inserção Manual e Memória**: Opção para digitar IP diretamente, salvamento automático do último IP e reconexão ao iniciar.
- **Design Neumórfico (Neu3D)**: Botões 3D com sombras claras e escuras em diagonal, efeito de botão afundado ao tocar, animação suave e feedback tátil (`HapticFeedback`).
- **Controles Completos**:
  - Liga/Desliga e Fonte de entrada (*Source*).
  - D-Pad direcional circular com repetição contínua ao segurar e botão central OK.
  - Balancins verticais de Volume (+/−) e Canal (^/v) com aceleração ao manter pressionado.
  - Teclado numérico completo (1-9, 0, INFO, MENU) e botões coloridos em *Bottom Sheets*.
  - Busca por Voz / Microfone com animação de ondas sonoras e envio direto para a TV.
  - Atalhos de streaming personalizáveis (Netflix, Prime Video, Globoplay, YouTube, Disney+, Max, Spotify, Apple TV+).
- **Barra Superior Completa**:
  - Indicador de status de conexão em tempo real.
  - Botão de Conectar / Buscar TVs (`settings_remote`).
  - Botão de Alternar Tema Automático / Claro / Escuro.
  - Botão de Configurações (`settings`):
    - Conectar automaticamente após primeiro acesso/vínculo com a TV.
    - Alterar modelo/design do controle conforme a marca (Samsung, LG webOS, Roku, Android TV / Google TV, Universal).
    - Seleção personalizada dos streamings favoritos nos atalhos do controle.
    - Ativação do botão de microfone para busca por voz.
  - Botão Sobre (`?`):
    - Exibição automática na primeira inicialização do app.
    - História da criação do app: proposta 100% gratuita, sem anúncios abusivos, feita de coração para facilitar a vida de todos.
    - QR Code oficial e chave PIX com botão de 1 clique para copiar.

---

## 🛠️ Como Compilar e Gerar o APK (Android)

### Pré-requisitos
- Flutter SDK (3.24+)
- Android SDK instalado com licenças aceitas (`flutter doctor --android-licenses`)

### Gerar APK Release
Execute no terminal:
```bash
cd controle_remoto_app
flutter build apk --release
```
O APK gerado estará localizado em:
`build/app/outputs/flutter-apk/app-release.apk`

Para instalar diretamente em um celular conectado via USB:
```bash
flutter install
# ou
flutter run --release
```

---

## 🍎 Como Compilar para iOS

> **Importante**: O desenvolvimento e build para iOS exigem um computador **macOS** com o **Xcode** instalado.

1. Clone ou transfira o projeto para o Mac.
2. Abra o terminal na pasta do projeto e instale as dependências:
   ```bash
   cd controle_remoto_app
   flutter pub get
   cd ios
   pod install
   cd ..
   ```
3. Abra a pasta `ios` no Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
4. Em **Signing & Capabilities**, selecione seu **Team** de desenvolvedor da Apple.
5. Para gerar o build de produção (IPA):
   ```bash
   flutter build ipa --release
   ```

---

## 📺 Instruções de Uso na TV Samsung

1. Conecte o celular na **mesma rede Wi-Fi** da TV Samsung (redes de 2.4 GHz e 5 GHz geralmente se comunicam se o isolamento de AP estiver desligado no roteador).
2. Abra o app:
   - Se for a primeira vez, o diálogo de busca abrirá automaticamente listando as TVs encontradas.
   - Você também pode digitar o endereço IP da TV manualmente (encontrado em *Configurações > Rede > Status da Rede > Configurações de IP* na TV).
3. **Primeira Conexão (Muito Importante)**:
   - Uma mensagem de confirmação aparecerá no canto da TV Samsung perguntando se você autoriza o aplicativo "Controle Remoto".
   - Use o controle físico original da TV para selecionar **"Permitir"**.
   - O aplicativo salvará o token recebido e se conectará automaticamente nas próximas vezes.
