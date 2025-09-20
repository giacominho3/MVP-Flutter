// lib/presentation/screens/main_screen.dart
import 'package:ai_assistant_mvp/presentation/screens/chat_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat/message_bubble.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _isPersonalPinsExpanded = true;
  bool _isOrgPinsExpanded = false;
  bool _isUtilitiesExpanded = false;
  
  @override
  void initState() {
    super.initState();
    // Crea una nuova sessione all'avvio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentChatSessionProvider.notifier).createNewSession();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final chatSession = ref.watch(currentChatSessionProvider);
    final messageState = ref.watch(messageStateProvider);
    final apiSettings = ref.watch(apiSettingsProvider);
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _buildLeftSidebar(),
          Expanded(
            child: _buildChatArea(chatSession, messageState, apiSettings),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeftSidebar() {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(
          right: BorderSide(color: AppColors.sidebarBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildApiKeyStatus(),
                  const SizedBox(height: 16),
                  _buildSessionReferences(),
                  const SizedBox(height: 24),
                  _buildPermanentReferences(),
                  const SizedBox(height: 24),
                  _buildUtilitiesSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: AppColors.background,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v.0.0.1',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.badgeBeta,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'beta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildApiKeyStatus() {
    final apiSettings = ref.watch(apiSettingsProvider);
    final hasApiKey = apiSettings.apiKey != null && apiSettings.apiKey!.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasApiKey ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasApiKey ? AppColors.success : AppColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasApiKey ? Icons.check_circle : Icons.warning,
            color: hasApiKey ? AppColors.success : AppColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasApiKey ? 'API Claude configurata' : 'Configura API Claude',
              style: TextStyle(
                fontSize: 12,
                color: hasApiKey ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!hasApiKey)
            TextButton(
              onPressed: _showApiKeyDialog,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text(
                'Configura',
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSessionReferences() {
    final chatSession = ref.watch(currentChatSessionProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riferimenti della Sessione',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            if (chatSession != null && chatSession.hasMessages)
              IconButton(
                onPressed: () {
                  ref.read(currentChatSessionProvider.notifier).createNewSession();
                },
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Nuova chat',
                style: IconButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.all(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),
        if (chatSession != null && chatSession.hasMessages)
          _buildReferenceItem(
            title: chatSession.title,
            badge: '${chatSession.messages.length} msg',
            badgeColor: AppColors.primary,
          )
        else
          const Text(
            'Nessuna conversazione attiva',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
  
  Widget _buildChatArea(chatSession, messageState, apiSettings) {
    if (chatSession == null) {
      return _buildWelcomeScreen(apiSettings);
    }
    
    return Column(
      children: [
        _buildChatHeader(chatSession),
        Expanded(
          child: _buildMessagesList(chatSession.messages),
        ),
        if (messageState is MessageStateError)
          _buildErrorBar(messageState.message),
        _buildChatInputArea(messageState),
      ],
    );
  }
  
  Widget _buildWelcomeScreen(apiSettings) {
    final hasApiKey = apiSettings.apiKey != null && apiSettings.apiKey!.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Benvenuto in AI Assistant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'La tua piattaforma AI per automatizzare i processi aziendali',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!hasApiKey) ...[
            ElevatedButton.icon(
              onPressed: _showApiKeyDialog,
              icon: const Icon(Icons.key),
              label: const Text('Configura API Claude'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Configura la tua API key di Claude per iniziare',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ] else ...[
            const Text(
              'Scrivi un messaggio per iniziare una nuova conversazione',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildChatHeader(chatSession) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chatSession.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${chatSession.messages.length} messaggi',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(currentChatSessionProvider.notifier).createNewSession();
            },
            icon: const Icon(Icons.add),
            tooltip: 'Nuova chat',
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessagesList(List<Message> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'Inizia una conversazione scrivendo un messaggio',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 16,
          ),
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showTimestamp = index == 0 || 
            messages[index - 1].timestamp.difference(message.timestamp).inMinutes.abs() > 5;
        
        return MessageBubble(
          message: message,
          showTimestamp: showTimestamp,
          onRetry: message.status == MessageStatus.error
              ? () => _retryMessage(message)
              : null,
        );
      },
    );
  }
  
  Widget _buildErrorBar(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppColors.error.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.error, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(messageStateProvider.notifier).setIdle();
            },
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatInputArea(messageState) {
    final isSending = messageState is MessageStateSending;
    final isEnabled = messageState is! MessageStateSending;
    
    return ChatInput(
      onSendMessage: _sendMessage,
      onCancel: isSending ? _cancelMessage : null,
      isEnabled: isEnabled,
      isSending: isSending,
    );
  }
  
  void _sendMessage(String content) {
    ref.read(currentChatSessionProvider.notifier).sendMessage(content);
    
    // Scroll to bottom after a delay to ensure message is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _cancelMessage() {
    ref.read(currentChatSessionProvider.notifier).cancelMessage();
  }
  
  void _retryMessage(Message message) {
    if (message.isUser && message.content.isNotEmpty) {
      _sendMessage(message.content);
    }
  }
  
  void _showApiKeyDialog() {
    final apiSettings = ref.read(apiSettingsProvider);
    final controller = TextEditingController(text: apiSettings.apiKey ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configura API Claude'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inserisci la tua API key di Claude:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'sk-ant-api...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Puoi ottenere la tua API key su console.anthropic.com',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final apiKey = controller.text.trim();
              if (apiKey.isNotEmpty) {
                try {
                  await ref.read(apiSettingsProvider.notifier).setApiKey(apiKey);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API key salvata con successo')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Errore: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
  
  // Resto dei metodi esistenti per la sidebar...
  Widget _buildPermanentReferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riferimenti Permanenti',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),
        _buildExpandableSection(
          icon: Icons.person_outline,
          title: 'I tuoi pin personali',
          isExpanded: _isPersonalPinsExpanded,
          onToggle: () => setState(() => _isPersonalPinsExpanded = !_isPersonalPinsExpanded),
          children: [
            _buildPinItem(
              title: 'Contabilità 2024',
              badge: 'G DRIVE',
              hasRemove: true,
            ),
            _buildPinItem(
              title: 'Contabilità 2023',
              badge: 'G DRIVE',
              hasRemove: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildExpandableSection(
          icon: Icons.business_outlined,
          title: 'Pin della tua organizzazione',
          isExpanded: _isOrgPinsExpanded,
          onToggle: () => setState(() => _isOrgPinsExpanded = !_isOrgPinsExpanded),
          children: [],
        ),
      ],
    );
  }
  
  Widget _buildUtilitiesSection() {
    return _buildExpandableSection(
      icon: Icons.lightbulb_outline,
      title: 'Scopri le funzionalità',
      isExpanded: _isUtilitiesExpanded,
      onToggle: () => setState(() => _isUtilitiesExpanded = !_isUtilitiesExpanded),
      children: [
        _buildUtilityItem(Icons.history, 'Storico Sessioni'),
        _buildUtilityItem(Icons.summarize_outlined, 'Riassunto sessione'),
        _buildUtilityItem(Icons.close, 'Termina sessione', isRed: true),
      ],
    );
  }
  
  Widget _buildReferenceItem({
    required String title,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandableSection({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.iconPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 16,
                  child: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.iconSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }
  
  Widget _buildPinItem({
    required String title,
    required String badge,
    bool hasRemove = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 24, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.badgeGoogleDrive,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasRemove) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.iconSecondary,
                ),
              ),
            ] else ...[
              const SizedBox(width: 24),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildUtilityItem(IconData icon, String title, {bool isRed = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 24, bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isRed ? AppColors.iconError : AppColors.iconSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isRed ? AppColors.iconError : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}