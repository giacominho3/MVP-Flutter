import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/message.dart';
import '../providers/chat_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isPersonalPinsExpanded = true;
  bool _isOrgPinsExpanded = true;
  bool _isUtilitiesExpanded = false;
  
  // Per la smart preview window
  List<String> selectedEmails = ['Oggetto mail #1', 'Oggetto mail #2'];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    
    // Listener per aggiornare il pulsante send quando cambia il testo
    _messageController.addListener(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final messageState = ref.read(messageStateProvider);
      if (messageState is! AppMessageStateSending) {
        ref.read(currentChatSessionProvider.notifier).sendMessage(text);
        _messageController.clear();
        _messageFocusNode.requestFocus();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final chatSession = ref.watch(currentChatSessionProvider);
    final messageState = ref.watch(messageStateProvider);
    
    // Auto-scroll quando arrivano nuovi messaggi
    ref.listen(currentChatSessionProvider, (previous, next) {
      if (next != null && previous != null) {
        if (next.messages.length > previous.messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    });
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // Sidebar sinistra
          _buildLeftSidebar(),
          
          // Area chat centrale
          Expanded(
            child: _buildChatArea(chatSession, messageState),
          ),
          
          // Smart Preview Window a destra
          _buildSmartPreviewWindow(),
        ],
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 48,
      leadingWidth: 56,
      leading: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset(
            'assets/images/logo_virgo.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback se l'immagine non viene trovata
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'V',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      title: Row(
        children: [
          const Text(
            'v.0.0.1',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.badgeBeta,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'beta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.iconPrimary),
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () {
                ref.read(authStateProvider.notifier).signOut();
              },
              child: const Row(
                children: [
                  Icon(Icons.logout, size: 16),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.divider,
          height: 1,
        ),
      ),
    );
  }
  
  Widget _buildLeftSidebar() {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(
          right: BorderSide(color: AppColors.sidebarBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Riferimenti della Sessione
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riferimenti della Sessione',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                _buildReferenceItem(
                  title: 'Nome File #1',
                  badge: 'G DRIVE',
                  badgeColor: AppColors.badgeGoogleDrive,
                ),
              ],
            ),
          ),
          
          // Riferimenti Permanenti
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riferimenti Permanenti',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 8),
                  
                  // I tuoi pin personali
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
                  
                  // Pin della tua organizzazione
                  _buildExpandableSection(
                    icon: Icons.business_outlined,
                    title: 'Pin della tua organizzazione',
                    isExpanded: _isOrgPinsExpanded,
                    onToggle: () => setState(() => _isOrgPinsExpanded = !_isOrgPinsExpanded),
                    children: [],
                  ),
                  
                  const Spacer(),
                  
                  // Utilities section in fondo
                  _buildExpandableSection(
                    icon: Icons.lightbulb_outline,
                    title: 'Scopri le funzionalità',
                    isExpanded: _isUtilitiesExpanded,
                    onToggle: () => setState(() => _isUtilitiesExpanded = !_isUtilitiesExpanded),
                    children: [
                      _buildUtilityItem(Icons.history, 'Storico Sessioni'),
                      _buildUtilityItem(Icons.article_outlined, 'Riassunto sessione'),
                      _buildUtilityItem(Icons.close, 'Termina sessione', isRed: true),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSmartPreviewWindow() {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.previewBackground,
        border: Border(
          left: BorderSide(color: AppColors.previewBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: const Center(
              child: Text(
                'Smart preview window',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          
          // Content area
          Expanded(
            child: selectedEmails.isNotEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Clicca per selezionare la mail corretta',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...selectedEmails.map((email) => _buildEmailPreview(email)),
                    ],
                  )
                : const Center(
                    child: Text(
                      'Nessun contenuto da visualizzare',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmailPreview(String subject) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Azione quando si clicca sull'email
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildChatArea(chatSession, messageState) {
    return Column(
      children: [
        // Messages area
        Expanded(
          child: Container(
            color: Colors.white,
            child: chatSession != null && chatSession.messages.isNotEmpty
                ? ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: chatSession.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatSession.messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildSimpleMessage(message),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo_virgo_extended.png',
                          width: 200,
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'VIRGO',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Inizia una conversazione',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        
        // Input area
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.outline, width: 1),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    enabled: messageState is! AppMessageStateSending,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Chiedimi qualsiasi cosa',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color.fromARGB(255, 80, 80, 80),
                      fontSize: 14,
                    ),
                    onSubmitted: (text) {
                      _sendMessage();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (messageState is AppMessageStateSending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _messageController.text.trim().isNotEmpty ? _sendMessage : null,
                    icon: Icon(
                      Icons.send,
                      color: _messageController.text.trim().isNotEmpty 
                          ? AppColors.primary 
                          : AppColors.iconSecondary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSimpleMessage(Message message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: message.isUser 
            ? AppColors.chatBubbleBg 
            : AppColors.assistantMessageBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                message.isUser ? Icons.person : Icons.smart_toy,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                message.isUser ? 'Tu' : 'Assistant',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (message.status == MessageStatus.sending)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Digitando...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            Text(
              message.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildReferenceItem({
    required String title,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              color: badgeColor,
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
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.iconPrimary),
                const SizedBox(width: 8),
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
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && children.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(children: children),
          ),
      ],
    );
  }
  
  Widget _buildPinItem({
    required String title,
    required String badge,
    bool hasRemove = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
            InkWell(
              onTap: () {
                // Remove pin action
              },
              child: const Icon(
                Icons.close,
                size: 14,
                color: AppColors.iconSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildUtilityItem(IconData icon, String title, {bool isRed = false}) {
    return InkWell(
      onTap: () {
        // Handle utility action
        if (title == 'Storico Sessioni') {
          // Apri storico
        } else if (title == 'Riassunto sessione') {
          // Genera riassunto
        } else if (title == 'Termina sessione') {
          // Termina sessione
          ref.read(currentChatSessionProvider.notifier).clearSession();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
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
      ),
    );
  }
}