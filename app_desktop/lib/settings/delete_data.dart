import 'dart:io';

/// Deletes what Charm saved for the user apart from its settings file (the
/// settings store resets that itself): the folder of charms they made, and
/// the error log. Photos they used for a charm are never in these places,
/// so they are never touched.
///
/// Returns the names of any it could not delete (files in use, say); empty
/// means everything went.
Future<List<String>> deleteUserData({
  required Directory charms,
  required File log,
}) async {
  final failed = <String>[];
  try {
    if (await charms.exists()) await charms.delete(recursive: true);
  } on FileSystemException {
    failed.add('your charms');
  }
  try {
    if (await log.exists()) await log.delete();
  } on FileSystemException {
    failed.add('the log');
  }
  return failed;
}
