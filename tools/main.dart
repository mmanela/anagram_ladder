import '../lib/anagram/anagramBuilder.dart';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print(
      "Please pass argument (build_ladders, repair_ladders or process_raw)",
    );
    return;
  }

  final builder = AnagramLadderBuilder();
  switch (arguments[0]) {
    case "build_ladders":
      await builder.buildLadders();
      break;
    case "repair_ladders":
      await builder.repairShortLadders();
      break;
    case "process_raw":
      await builder.processRawWords();
      break;
    default:
      break;
  }
}
