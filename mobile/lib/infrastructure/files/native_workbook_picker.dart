import 'package:file_selector/file_selector.dart';

import '../../domain/course_authoring/course_authoring.dart';

final class NativeWorkbookPicker implements WorkbookPicker {
  const NativeWorkbookPicker();

  static const _workbookType = XTypeGroup(
    label: 'Excel workbook',
    extensions: ['xlsx'],
    mimeTypes: [workbookMediaType],
    uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet'],
  );

  @override
  Future<SelectedWorkbook?> pickWorkbook() async {
    final selected = await openFile(acceptedTypeGroups: const [_workbookType]);
    if (selected == null) {
      return null;
    }
    final size = await selected.length();
    return SelectedWorkbook(
      displayName: selected.name,
      sizeBytes: size,
      readRange: (start, endExclusive) =>
          selected.openRead(start, endExclusive),
    );
  }
}
