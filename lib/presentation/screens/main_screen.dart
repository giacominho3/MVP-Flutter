import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isPersonalPinsExpanded = true;
  bool _isOrgPinsExpanded = false;
  bool _isUtilitiesExpanded = false;
  final TextEditingController _messageController = TextEditingController();
  
  bool _isChatSelected = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _buildLeftSidebar(),
          Expanded(
            child: _isChatSelected ? _buildSelectionPreview() : _buildStartingPage(),
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
  
  Widget _buildSessionReferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),
        _buildReferenceItem(
          title: 'Nome File #1',
          badge: 'G DRIVE',
          badgeColor: AppColors.badgeGoogleDrive,
        ),
      ],
    );
  }
  
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
              onTap: () => _selectChat(),
            ),
            _buildPinItem(
              title: 'Contabilità 2023',
              badge: 'G DRIVE',
              hasRemove: true,
              onTap: () => _selectChat(),
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

  Widget _buildStartingPage() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: AppColors.background,
            child: const Center(
              child: Text(
                'Smart preview window',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        _buildInputArea(),
      ],
    );
  }
  
  Widget _buildSelectionPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.previewBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.previewBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'Smart preview window',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildChatBubbles(),
                const SizedBox(height: 16),
                _buildEmailSelection(),
              ],
            ),
          ),
        ),
        _buildInputArea(),
      ],
    );
  }
  
  Widget _buildChatBubbles() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.userMessageBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Cerca la mail in cui ho mandato il preventivo al nostro ultimo cliente e mostrami gli allegati',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.assistantMessageBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Cerca la mail in cui ho mandato il preventivo al nostro ultimo cliente e mostrami gli allegati',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmailSelection() {
    return Column(
      children: [
        Text(
          'Clicca per selezionare la mail corretta',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Text(
                  'Oggetto mail #1',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Text(
                  'Oggetto mail #2',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.iconSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Chiedimi qualsiasi cosa',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                  ),
                ),
                maxLines: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _selectChat() {
    setState(() {
      _isChatSelected = true;
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}