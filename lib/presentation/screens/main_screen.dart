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
  bool _isPreviewVisible = true;
  double _sidebarWidth = 300;
  double _previewWidth = 400;
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      drawer: isSmallScreen ? _buildSidebar() : null,
      body: Row(
        children: [
          // Left Sidebar (Hidden on small screens)
          if (!isSmallScreen) _buildSidebar(),
          
          // Main Chat Area
          Expanded(
            child: _buildChatArea(),
          ),
          
          // Right Preview Panel (Collapsible)
          if (_isPreviewVisible && !isSmallScreen) _buildPreviewPanel(),
        ],
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.smart_toy_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('AI Assistant v1.0'),
        ],
      ),
      actions: [
        // Preview toggle button
        IconButton(
          icon: Icon(_isPreviewVisible ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isPreviewVisible = !_isPreviewVisible),
          tooltip: 'Toggle Preview',
        ),
        
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => _navigateToSettings(),
          tooltip: 'Settings',
        ),
        
        const SizedBox(width: 8),
      ],
    );
  }
  
  Widget _buildSidebar() {
    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Session References
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Riferimenti Sessione',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          Expanded(
            flex: 1,
            child: _buildSessionReferences(),
          ),
          
          // Permanent References
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Riferimenti Permanenti',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          Expanded(
            flex: 2,
            child: _buildPermanentReferences(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionReferences() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildReferenceItem(
          icon: Icons.folder_rounded,
          title: 'Budget Q4 2024.xlsx',
          subtitle: 'GOOGLE DRIVE',
          color: AppColors.fileSpreadsheet,
        ),
        _buildReferenceItem(
          icon: Icons.description_rounded,
          title: 'Report Vendite.pdf',
          subtitle: 'LOCAL',
          color: AppColors.fileDocument,
        ),
        _buildReferenceItem(
          icon: Icons.search_rounded,
          title: 'Query: fatture 2024',
          subtitle: '34 file trovati',
          color: AppColors.secondary,
        ),
      ],
    );
  }
  
  Widget _buildPermanentReferences() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildPinCategory(
          icon: Icons.bar_chart_rounded,
          title: 'Contabilità 2024',
          isExpanded: true,
          children: [
            _buildSubPin(
              icon: Icons.assessment_rounded,
              title: 'Report Mensili',
            ),
            _buildSubPin(
              icon: Icons.receipt_rounded,
              title: 'Fatture',
            ),
          ],
        ),
        
        _buildPinCategory(
          icon: Icons.bar_chart_outlined,
          title: 'Contabilità 2023',
          isExpanded: false,
        ),
        
        _buildPinCategory(
          icon: Icons.business_rounded,
          title: 'Pin Organizzazione',
          isExpanded: true,
          children: [
            _buildSubPin(
              icon: Icons.group_rounded,
              title: 'Progetti Cliente',
            ),
            _buildSubPin(
              icon: Icons.assignment_rounded,
              title: 'Contratti Attivi',
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildChatArea() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
      ),
      child: Column(
        children: [
          // Chat Messages Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Inizia una conversazione',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chiedimi qualsiasi cosa sui tuoi documenti aziendali',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Chat Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: _buildChatInput(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Chiedimi qualsiasi cosa...',
              prefixIcon: const Icon(Icons.chat_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded),
                    onPressed: () => _attachFile(),
                    tooltip: 'Allega file',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Invia'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 40),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            maxLines: null,
            textInputAction: TextInputAction.newline,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPreviewPanel() {
    return Container(
      width: _previewWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Preview Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.preview_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Smart Preview Window',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => setState(() => _isPreviewVisible = false),
                  tooltip: 'Chiudi preview',
                ),
              ],
            ),
          ),
          
          // Preview Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nessun contenuto da visualizzare',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seleziona un file o avvia una conversazione per vedere l\'anteprima',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReferenceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, size: 16, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
  
  Widget _buildPinCategory({
    required IconData icon,
    required String title,
    required bool isExpanded,
    List<Widget>? children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, size: 18, color: AppColors.pinActive),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          initiallyExpanded: isExpanded,
          dense: true,
          visualDensity: VisualDensity.compact,
          children: children ?? [],
        ),
      ),
    );
  }
  
  Widget _buildSubPin({
    required IconData icon,
    required String title,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 32, bottom: 4),
      child: ListTile(
        leading: Icon(icon, size: 14, color: AppColors.textSecondary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12),
        ),
        dense: true,
        visualDensity: VisualDensity.compact,
        onTap: () => _selectPin(title),
      ),
    );
  }
  
  void _navigateToSettings() {
    // TODO: Navigate to settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings non ancora implementato')),
    );
  }
  
  void _attachFile() {
    // TODO: Implement file attachment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funzione allega file non ancora implementata')),
    );
  }
  
  void _sendMessage() {
    // TODO: Implement send message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invio messaggi non ancora implementato')),
    );
  }
  
  void _selectPin(String pinName) {
    // TODO: Implement pin selection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pin selezionato: $pinName')),
    );
  }
}