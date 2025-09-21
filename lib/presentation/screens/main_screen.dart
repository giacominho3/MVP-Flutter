import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/datasources/remote/supabase_service.dart';
import '../../domain/entities/chat_session.dart';
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
  List<String> selectedEmails = [];
  
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
      body: Column(
        children: [
          // Custom Header invece di AppBar
          _buildCustomHeader(),
          
          // Contenuto principale
          Expanded(
            child: Row(
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomHeader() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Sezione logo con larghezza fissa (stessa della sidebar)
          Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.sidebarBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Logo allineato a sinistra
                Image.asset(
                  'assets/images/logo_virgo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
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
                
                // Spacer per spingere versione e beta a destra
                const Spacer(),
                
                // Versione e Beta allineati a destra
                const Text(
                  'v.0.0.1',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                
                // Badge Beta con font size 12
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 229, 232),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'beta',
                    style: TextStyle(
                      color: Color.fromARGB(255, 223, 4, 95),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Sezione centrale (vuota per ora, puoi aggiungere titolo chat o altro)
          const Expanded(
            child: SizedBox(),
          ),
          
          // Sezione destra con menu
          Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.previewBorder, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeftSidebar() {
    // Carica le sessioni chat
    final chatSessionsAsync = ref.watch(chatSessionsProvider);
    final currentSession = ref.watch(currentChatSessionProvider);
    
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
                if (currentSession != null)
                  _buildReferenceItem(
                    title: currentSession.title,
                    badge: 'ATTIVA',
                    badgeColor: AppColors.success,
                  )
                else
                  const Text(
                    'Nessuna sessione attiva',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
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
                  
                  // Container con bordo per "Le tue conversazioni"
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFC), // Grigio molto chiaro, appena percettibile
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.outline,
                        width: 1,
                      ),
                    ),
                    child: _buildExpandableSection(
                      icon: Icons.person_outline,
                      title: 'Le tue conversazioni',
                      isExpanded: _isPersonalPinsExpanded,
                      onToggle: () => setState(() => _isPersonalPinsExpanded = !_isPersonalPinsExpanded),
                      children: chatSessionsAsync.when(
                        data: (sessions) {
                          if (sessions.isEmpty) {
                            return [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Nessuna conversazione salvata',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ];
                          }
                          return sessions.map((session) => _buildChatItem(
                            session: session,
                            isActive: currentSession?.id == session.id,
                          )).toList();
                        },
                        loading: () => [
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        ],
                        error: (error, _) => [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Errore nel caricamento',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Container con bordo per "Pin della tua organizzazione"
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFC), // Grigio molto chiaro
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.outline,
                        width: 1,
                      ),
                    ),
                    child: _buildExpandableSection(
                      icon: Icons.business_outlined,
                      title: 'Pin della tua organizzazione',
                      isExpanded: _isOrgPinsExpanded,
                      onToggle: () => setState(() => _isOrgPinsExpanded = !_isOrgPinsExpanded),
                      children: [],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Utilities section in fondo
                  _buildExpandableSection(
                    icon: Icons.lightbulb_outline,
                    title: 'Scopri le funzionalità',
                    isExpanded: _isUtilitiesExpanded,
                    onToggle: () => setState(() => _isUtilitiesExpanded = !_isUtilitiesExpanded),
                    children: [
                      _buildUtilityItem(Icons.add_comment, 'Nuova conversazione'),
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
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.iconPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
            padding: const EdgeInsets.only(left: 26, right: 12, bottom: 10),
            child: Column(children: children),
          ),
      ],
    );
  }
  
  Widget _buildChatItem({
    required ChatSession session,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.hoverLight : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: () {
          // Carica la sessione selezionata
          ref.read(currentChatSessionProvider.notifier).loadSession(session);
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                        color: isActive ? AppColors.primary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSessionDate(session.updatedAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'ATTIVA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 14,
                  color: AppColors.iconSecondary,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Elimina', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(session);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation(ChatSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina conversazione'),
        content: Text('Sei sicuro di voler eliminare "${session.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Se è la sessione corrente, eliminala
              final currentSession = ref.read(currentChatSessionProvider);
              if (currentSession?.id == session.id) {
                ref.read(currentChatSessionProvider.notifier).deleteCurrentSession();
              } else {
                // Altrimenti elimina direttamente dal database
                SupabaseService.deleteChatSession(session.id).then((_) {
                  // Aggiorna la lista
                  ref.invalidate(chatSessionsProvider);
                });
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
  
  String _formatSessionDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Adesso';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min fa';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ore fa';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildUtilityItem(IconData icon, String title, {bool isRed = false}) {
    return InkWell(
      onTap: () {
        // Handle utility action
        if (title == 'Nuova conversazione') {
          // Crea nuova sessione
          ref.read(currentChatSessionProvider.notifier).createNewSession();
        } else if (title == 'Riassunto sessione') {
          // Genera riassunto (da implementare)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Funzionalità in arrivo!')),
          );
        } else if (title == 'Termina sessione') {
          // Termina sessione corrente
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