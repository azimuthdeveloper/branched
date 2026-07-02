import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../core/locator.dart';
import '../../core/file_picker_service.dart';
import '../repository_manager/repository_manager_bloc.dart';

class WindowChrome extends StatelessWidget {
  final Widget child;

  const WindowChrome({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTitleBar(context),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return BlocBuilder<RepositoryManagerBloc, RepositoryManagerState>(
      builder: (context, state) {
        return Container(
          height: 38,
          color: FurcateTheme.darkBgTitlebar,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // macOS style Traffic Lights placeholder
              Row(
                children: [
                  _buildTrafficLight(Colors.red),
                  const SizedBox(width: 6),
                  _buildTrafficLight(Colors.amber),
                  const SizedBox(width: 6),
                  _buildTrafficLight(Colors.green),
                ],
              ),
              const SizedBox(width: 20),

              // Tabs
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.openTabs.length,
                  itemBuilder: (context, index) {
                    final tab = state.openTabs[index];
                    final isActive = index == state.activeTabIndex;

                    return GestureDetector(
                      onTap: () {
                        context.read<RepositoryManagerBloc>().add(SwitchTabEvent(index));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 6, right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isActive ? FurcateTheme.darkBgPrimary : FurcateTheme.darkBgToolbar,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: isActive ? Colors.transparent : FurcateTheme.darkBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              tab.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? FurcateTheme.darkTextEmphasis : FurcateTheme.darkTextSecondary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (tab.isDirty) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: FurcateTheme.darkAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                context.read<RepositoryManagerBloc>().add(CloseRepositoryEvent(index));
                              },
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: isActive ? FurcateTheme.darkTextPrimary : FurcateTheme.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Plus button to open repo via native directory picker
              IconButton(
                icon: const Icon(Icons.add, size: 18, color: FurcateTheme.darkTextPrimary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final selectedDir = await locator<FilePickerService>().getDirectoryPath(
                    dialogTitle: 'Open Git Repository',
                  );
                  if (selectedDir == null) return; // User cancelled
                  if (!context.mounted) return;
                  context.read<RepositoryManagerBloc>().add(OpenRepositoryEvent(selectedDir));
                },
              ),
              const SizedBox(width: 8),

              // Embedded Git Hash in custom title bar
              const Text(
                String.fromEnvironment('GIT_HASH', defaultValue: 'local'),
                style: TextStyle(
                  fontSize: 10,
                  color: FurcateTheme.darkTextSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 16),

              // Window minimize/maximize/close buttons placeholders
              const Icon(Icons.remove, size: 16, color: FurcateTheme.darkTextSecondary),
              const SizedBox(width: 12),
              const Icon(Icons.crop_square, size: 14, color: FurcateTheme.darkTextSecondary),
              const SizedBox(width: 12),
              const Icon(Icons.close, size: 16, color: FurcateTheme.darkTextSecondary),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrafficLight(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        shape: BoxShape.circle,
      ),
    );
  }
}
