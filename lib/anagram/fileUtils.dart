import 'dart:io';

Future<List<String>> linesFromFile(String name) async {
  var input = File(name);
  var contents = await input.readAsLines();
  return contents;
}
