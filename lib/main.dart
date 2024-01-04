import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:tuple/tuple.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LabelState(),
      child: MaterialApp(
        title: 'OpenIE Annotator',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class Word {
  final String text;
  final int index;

  Word(this.text, this.index) {
    if (text.isEmpty) {
      throw ArgumentError();
    }
  }

  @override
  String toString() {
    return text;
  }
}

var andWord = Word('AND', -1);
var orWord = Word('OR', -1);
var noneWord = Word('-', -1);
var beWord = Word('BE', -1);

String wordsToString(List<Word> words) {
  var strings = <String>[];
  for (var word in words) {
    strings.add(word.text);
  }
  return strings.join(' ');
}

class Relation {
  dynamic subject; // optional type of [null, List<Words>, Relation]
  dynamic predicate;
  dynamic object;

  bool subjectOptional = false;
  bool predicateOptional = false;
  bool objectOptional = false;

  List<Word> subjectPronoun = <Word>[];
  List<Word> predicatePronoun = <Word>[];
  List<Word> objectPronoun = <Word>[];

  Relation({this.subject, this.predicate, this.object});

  static dynamic seriesElement(dynamic value) {
    if (value == null) return '';

    if (value is List<Word>) {
      return [
        for (var word in value) {'index': word.index, 'text': word.text}
      ];
    } else if (value is Relation) {
      return value.toJson();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': {
        'content': seriesElement(subject),
        'isOptional': subjectOptional,
        'pronoun': seriesElement(subjectPronoun),
      },
      'predicate': {
        'content': seriesElement(predicate),
        'isOptional': predicateOptional,
        'pronoun': seriesElement(predicatePronoun),
      },
      'object': {
        'content': seriesElement(object),
        'isOptional': objectOptional,
        'pronoun': seriesElement(objectPronoun),
      },
    };
  }

  void splitSubject() {
    subject = Relation();
  }

  void splitPredicate() {
    predicate = Relation();
  }

  void splitObject() {
    object = Relation();
  }
}

// enum SentenceType {
//   simpleSentece,
//   complexSentece,
//   compoundSentence,
//   compoundComplexSentence
// }

// // enum ClauseType {
// //   subjectVerb,
// //   subjectVerbAdverbial,
// //   subjectVerbObject,
// //   subjectVerbComplement,
// //   subjectVerbObjectObject,
// //   subjectVerbObjectAdverbial,
// //   subjectVerbObjectComplement,
// // }

enum SentenceElementType {
  subject,
  predicate,
  object,
  complement,
  adverbial,
}

// enum ComplexType {
//   adverbialClause,
//   adnominalClause,
// }

class SentenceElement {
  final SentenceElementType elementType;
  final SentenceElement? clauseStructure;

  SentenceElement(this.elementType, [this.clauseStructure]);
}

class SentenceStructure {
  var sentenceElements = <SentenceElement>[];
}

class LabelState extends ChangeNotifier {
  var sentence = 'Please Open a file';
  // '32.7 % of all households were made up of individuals and 15.7 % had someone living alone who was 65 years of age or older .';

  var sentences = <String>[];
  var indexController = TextEditingController();

  var sentenceController = TextEditingController();
  var currentIndex = 0;
  String filename = '';
  String saveDirectory = '';
  var sentenceType = '';
  var clauseTypes = MainAxisAlignment.center;

  var structureController = TextEditingController();

  var words = <Word>[
    andWord, orWord, beWord
    // Word('32.7%', 0),
    // Word('of', 1),
    // Word('all', 2),
    // Word('households', 3),
    // Word('were', 4),
    // Word('made', 5),
    // Word('up', 6),
    // Word('of', 22),
    // Word('individuals', 7),
    // Word('and', 8),
    // Word('15.7%', 9),
    // Word('had', 10),
    // Word('someone', 11),
    // Word('living', 12),
    // Word('alone', 13),
    // Word('who', 14),
    // Word('was', 15),
    // Word('65', 16),
    // Word('years', 17),
    // Word('of', 18),
    // Word('age', 19),
    // Word('or', 20),
    // Word('older', 21),
  ];

  var selectedWords = <Word>[];

  void removeSelected(Word word) {
    selectedWords.remove(word);
    notifyListeners();
  }

  void addSelected(Word word) {
    selectedWords.add(word);
    notifyListeners();
  }

  var relations = <Relation>[
    Relation(subject: Relation(), predicate: Relation(), object: Relation())
  ];

  void reset() {
    relations = <Relation>[
      Relation(subject: Relation(), predicate: Relation(), object: Relation())
    ];
    notifyListeners();
  }

  void addRelation() {
    relations.add(Relation(
        subject: Relation(), predicate: Relation(), object: Relation()));
    notifyListeners();
  }

  void split(Relation relation, position) {
    if (position == 'subject') {
      relation.splitSubject();
    } else if (position == 'predicate') {
      relation.splitPredicate();
    } else if (position == 'object') {
      relation.splitObject();
    } else {
      throw Exception('invalid relation $relation and position $position');
    }
    notifyListeners();
  }

  void toggleOptional(List<Word> relation, Relation parent) {
    if (parent.subject == relation) {
      parent.subjectOptional = !parent.subjectOptional;
    } else if (parent.predicate == relation) {
      parent.predicateOptional = !parent.predicateOptional;
    } else if (parent.object == relation) {
      parent.objectOptional = !parent.objectOptional;
    } else {
      throw Exception('invalid relation $relation and parent $parent');
    }

    notifyListeners();
  }

  bool isOptional(List<Word> relation, Relation parent) {
    if (parent.subject == relation) {
      return parent.subjectOptional;
    } else if (parent.predicate == relation) {
      return parent.predicateOptional;
    } else if (parent.object == relation) {
      return parent.objectOptional;
    }
    return false;
  }

  void labelPronoun(List<Word> relation, Relation parent) {
    if (parent.subject == relation) {
      parent.subjectPronoun = sortSelectedWords().toList();
    } else if (parent.predicate == relation) {
      parent.predicatePronoun = sortSelectedWords().toList();
    } else if (parent.object == relation) {
      parent.objectPronoun = sortSelectedWords().toList();
    }

    selectedWords.clear();
    notifyListeners();
  }

  List<Word> sortSelectedWords() {
    selectedWords.sort((w1, w2) => w1.index.compareTo(w2.index));
    return selectedWords;
  }

  void label(Relation relation, position) {
    if (selectedWords.isEmpty) {
      return;
    }
    var sWords = sortSelectedWords().toList();
    if (position == 'subject') {
      relation.subject = sWords;
    } else if (position == 'predicate') {
      relation.predicate = sWords;
    } else if (position == 'object') {
      relation.object = sWords;
    }
    selectedWords.clear();
    notifyListeners();
  }

  void delete(Relation relation, dynamic position) {
    if (position is String) {
      if (position == 'subject') {
        relation.subject = null;
        relation.subjectOptional = false;
        relation.subjectPronoun = [];
      } else if (position == 'predicate') {
        relation.predicate = null;
        relation.predicateOptional = false;
        relation.predicatePronoun = [];
      } else if (position == 'object') {
        relation.object = null;
        relation.objectOptional = false;
        relation.objectPronoun = [];
      }
    } else if (position is Relation) {
      if (position.subject == relation) {
        position.subject = null;
        relation.subjectOptional = false;
        relation.subjectPronoun = [];
      } else if (position.predicate == relation) {
        position.predicate = null;
        relation.predicateOptional = false;
        relation.predicatePronoun = [];
      } else if (position.object == relation) {
        position.object = null;
        relation.objectOptional = false;
        relation.objectPronoun = [];
      }
    }

    notifyListeners();
  }

  void mergeAs(Relation relation, String position, Relation? parent) {
    Relation newRelation = Relation();
    if (position == 'subject') {
      newRelation = Relation(subject: relation);
    } else if (position == 'predicate') {
      newRelation = Relation(predicate: relation);
    } else if (position == 'object') {
      newRelation = Relation(object: relation);
    }

    if (parent!.subject == relation) {
      parent.subject = newRelation;
    } else if (parent.predicate == relation) {
      parent.predicate = newRelation;
    } else if (parent.object == relation) {
      parent.object = newRelation;
    }

    notifyListeners();
  }

  void pickOpenFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result == null) return;
    saveDirectory = '';

    final file = File(result.files.first.path!);

    sentences = await file.readAsLines();
    if (file.path.split('\\').last == 'dev.txt') {
      filename = 'dev';
    } else if (file.path.split('\\').last == 'test.txt') {
      filename = 'test';
    } else {
      // TODO: benchie
      throw Exception('invalid input file ${file.path}');
    }

    jumpTo(0);
    notifyListeners();
  }

  void getNext() {
    if (structureController.text.isNotEmpty) {
      save(sentence, currentIndex, structureController.text, relations);
    }

    jumpTo(currentIndex + 1);
  }

  void jumpTo(int destIndex) {
    if (destIndex < 0 ||
        (sentences.isNotEmpty && destIndex >= sentences.length)) {
      return;
    }
    sentence = sentences[destIndex];
    sentence = '${sentence[0].toLowerCase()}${sentence.substring(1)}';
    sentence[0].toLowerCase();
    sentenceController.text = sentence;
    structureController.text = '';
    currentIndex = destIndex;
    tokenize();
    reset();
    indexController.text = (destIndex + 1).toString();

    notifyListeners();
  }

  void tokenize() {
    words.clear();
    sentenceController.text
        .split(' ')
        .asMap()
        .forEach((int index, String word) {
      words.add(Word(word, index));
    });

    words.addAll([andWord, orWord, beWord]);

    // var url =
    //     Uri.http('127.0.0.1:5000', '/', {'sentence': sentenceController.text});
    // var data = await http.get(url);
    // jsonDecode(data.body)['words'].asMap().forEach((int index, dynamic word) {
    //   words.add(Word(word as String, index));
    // });

    notifyListeners();
  }

  String getElementName(String token) {
    switch (token) {
      case 'S':
        return 'subject';
      case 'V':
        return 'verb';
      case 'O':
        return 'object';
      case 'C':
        return 'complement';
      case 'A':
        return 'adverbial';
    }
    return '';
  }

  Tuple2<Map<String, dynamic>, int> parseClauseStructure(String text) {
    var result = <String, dynamic>{};
    var offset = text.lastIndexOf('}');
    // skip `{`
    result['clauseType'] = getElementName(text[1]);
    result['clauseStructure'] = parseStructure(text.substring(3, offset));

    return Tuple2(result, offset);
  }

  List<dynamic> parseStructure(String text) {
    var result = <dynamic>[];
    for (var index = 0; index < text.length; index++) {
      var token = text[index];
      if (getElementName(token) != '') {
        result.add(getElementName(token));
      } else if (token == '{') {
        var tuple = parseClauseStructure(text.substring(index));
        result.add(tuple.item1);
        index += tuple.item2;
      } else {
        throw Exception('invalid syntax $text');
      }
    }
    return result;
  }

  Future<void> save(String inputSentence, int destIndex, String structureText,
      List<Relation> labeledRelations) async {
    if (saveDirectory == '') {
      var result = await FilePicker.platform.getDirectoryPath();
      if (result == null) {
        return;
      }
      saveDirectory = result;
    }

    var structure = <dynamic>[];
    structureText
        .toUpperCase()
        .split('-')
        .toList()
        .asMap()
        .forEach((index, clause) => structure.add(parseStructure(clause)));

    var relationsJson = <dynamic>[];
    labeledRelations
        .asMap()
        .forEach((index, relation) => relationsJson.add(relation.toJson()));

    var data = {
      'sentence': inputSentence,
      'structure': structure,
      'relations': relationsJson,
    };

    final destFile = File('$saveDirectory\\${destIndex + 1}.json');
    destFile.writeAsString(JsonEncoder.withIndent('  ').convert(data));
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var labelState = context.watch<LabelState>();

    // The words that can be selected as label
    var filterChips = <FilterChip>[];
    for (var i = 0; i < labelState.words.length; i++) {
      filterChips.add(FilterChip(
          label: Text(labelState.words[i].text),
          selected: labelState.selectedWords.contains(labelState.words[i]),
          onSelected: (value) {
            if (value == false) {
              labelState.removeSelected(labelState.words[i]);
            } else {
              labelState.addSelected(labelState.words[i]);
            }
          }));
    }

    var functionalFilterChips = filterChips.sublist(filterChips.length - 3);
    filterChips.removeRange(filterChips.length - 3, filterChips.length);

    // The relations showing
    var relationElements = <RelationWidget>[];
    for (var relation in labelState.relations) {
      relationElements.add(RelationWidget(relation: relation, parent: null));
    }

    return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(labelState.sentence),
            Padding(padding: const EdgeInsets.only(top: 20)),
            Text(labelState.sentence, style: TextStyle(fontSize: 15)),
            Divider(height: 3.0, color: Colors.grey),
            Padding(padding: const EdgeInsets.only(top: 10)),
            Row(
              children: [
                IconButton(
                    onPressed: () {
                      labelState.tokenize();
                    },
                    tooltip: 'Re-tokenize',
                    icon: Icon(Icons.refresh)),
                Expanded(
                  child: TextFormField(
                    maxLines: null,
                    obscureText: false,
                    // initialValue: labelState.sentence,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Sentence',
                    ),
                    controller: labelState.sentenceController,
                  ),
                ),
              ],
            ),
            Padding(padding: const EdgeInsets.all(5)),
            Divider(height: 3.0, color: Colors.grey),
            Padding(padding: const EdgeInsets.all(5)),
            Wrap(spacing: 3, runSpacing: 6, children: filterChips),
            Padding(padding: const EdgeInsets.all(5)),
            Divider(height: 3.0, color: Colors.grey),
            Padding(padding: const EdgeInsets.all(5)),
            Wrap(spacing: 3, runSpacing: 6, children: functionalFilterChips),
            Padding(padding: const EdgeInsets.all(5)),
            Divider(height: 3.0, color: Colors.grey),
            TextField(
              controller: labelState.structureController,
              // style: TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              // decoration: InputDecoration(suffix: Text('/123')),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[SVOCAsvoca\-:{}]'),
                ),
              ],
              decoration: InputDecoration(
                  hintText:
                      'SV / SVA / SVC / SVO / SVOO / SVOA / SVOC / (complex) SV{O:SVO} / (compound) SVO-SVA / (compound-complex) SV{O:SVO}'),
              // onSubmitted: (String? value) {
              //   if (value != null) {
              //     labelState.jumpTo(int.parse(value) - 1);
              //   }
              // },
            ),
            Expanded(
                // height: 1000,
                child: ListView.separated(
              itemBuilder: (context, index) {
                return Container(
                  padding: EdgeInsets.only(top: 20, bottom: 20),
                  child: relationElements[index],
                );
              },
              separatorBuilder: (BuildContext context, int index) =>
                  Divider(height: 3.0, color: Colors.grey),
              itemCount: relationElements.length,
            )),
            Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(labelState.filename),
                        // IntrinsicWidth(
                        SizedBox(
                          width: 40,
                          child: TextField(
                            controller: labelState.indexController,
                            // style: TextStyle(fontSize: 10),
                            textAlign: TextAlign.end,
                            // decoration: InputDecoration(suffix: Text('/123')),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]'),
                              ),
                            ],
                            onSubmitted: (String? value) {
                              if (value != null) {
                                labelState.jumpTo(int.parse(value) - 1);
                              }
                            },
                          ),
                        ),

                        Text('/'
                            '${labelState.sentences.isEmpty ? '-' : labelState.sentences.length} '),
                        // ]),
                      ]),
                  SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(Colors.blue),
                      value: labelState.sentences.isNotEmpty
                          ? labelState.currentIndex /
                              labelState.sentences.length
                          : 0,
                    ),
                  ),
                ]),
          ],
        ),
        floatingActionButton: Container(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: labelState.pickOpenFile,
                tooltip: 'Open File',
                child: Icon(Icons.file_copy),
              ),
              FloatingActionButton(
                onPressed: labelState.addRelation,
                tooltip: 'Add a relation',
                child: Icon(Icons.add),
              ),
              FloatingActionButton(
                onPressed: labelState.reset,
                tooltip: 'Reset',
                child: Icon(Icons.refresh),
              ),
              FloatingActionButton(
                onPressed: labelState.getNext,
                tooltip: 'Next',
                child: Icon(Icons.arrow_right_alt),
              ),
            ],
          ),
        ));
  }
}

class RelationWidget extends StatelessWidget {
  final Relation relation;
  final Relation? parent;

  const RelationWidget({
    super.key,
    required this.relation,
    required this.parent,
  });

  Widget renderRelationElement(dynamic element, String position,
      Relation parent, LabelState labelState) {
    // Display the

    var color;
    if (position == 'subject') {
      color = Colors.green;
    } else if (position == 'predicate') {
      color = Colors.orange;
    } else if (position == 'object') {
      color = Colors.blue;
    }

    if (element is List<Word>) {
      var children = [
        IconButton(
          onPressed: () => {labelState.split(parent, position)},
          icon: Icon(Icons.splitscreen),
          color: color,
          tooltip: 'split',
        ),
        IconButton(
            onPressed: () => {labelState.delete(parent, position)},
            icon: Icon(Icons.delete),
            color: color),
        // optional toggle button
        ToggleButtons(
          onPressed: (index) => {labelState.toggleOptional(element, parent)},
          isSelected: [labelState.isOptional(element, parent)],
          children: [Icon(Icons.rule)],
        ),
      ];

      if (position == 'subject' && parent.subjectPronoun.isNotEmpty) {
        children.add(
          Text(
            wordsToString(parent.subjectPronoun),
            style: TextStyle(color: color, fontSize: 15),
          ),
        );
      } else if (position == 'predicate' &&
          parent.predicatePronoun.isNotEmpty) {
        children.add(
          Text(
            wordsToString(parent.predicatePronoun),
            style: TextStyle(color: color, fontSize: 15),
          ),
        );
      } else if (position == 'object' && parent.objectPronoun.isNotEmpty) {
        children.add(
          Text(
            wordsToString(parent.objectPronoun),
            style: TextStyle(color: color, fontSize: 15),
          ),
        );
      } else {
        children.add(IconButton(
          onPressed: () => {labelState.labelPronoun(element, parent)},
          icon: Icon(Icons.people_alt),
          color: color,
          tooltip: 'pronoun resolution',
        ));
      }

      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          wordsToString(element),
          style: TextStyle(color: color, fontSize: 20),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: children),
      ]);
    } else if (element is Relation) {
      return RelationWidget(relation: element, parent: parent);
    } else if (element == null) {
      return Wrap(spacing: 3.0, children: [
        IconButton.outlined(
            onPressed: () => {labelState.label(parent, position)},
            icon: const Icon(Icons.download),
            color: color),
        IconButton.outlined(
          onPressed: () => {labelState.split(parent, position)},
          icon: const Icon(Icons.splitscreen),
          color: color,
        ),
      ]);
    }

    throw UnimplementedError('unknoown elemnt $element');
  }

  @override
  Widget build(BuildContext context) {
    var labelState = context.watch<LabelState>();

    var elementChildren = <Widget>[];
    elementChildren.add(renderRelationElement(
        relation.subject, 'subject', relation, labelState));
    elementChildren.add(renderRelationElement(
        relation.predicate, 'predicate', relation, labelState));
    elementChildren.add(
        renderRelationElement(relation.object, 'object', relation, labelState));

    var mergeChildren = <Widget>[];

    if (!labelState.relations.contains(relation)) {
      mergeChildren.addAll([
        IconButton.filledTonal(
            onPressed: () => {labelState.mergeAs(relation, 'subject', parent)},
            icon: Text('S')),
        IconButton.filledTonal(
            onPressed: () =>
                {labelState.mergeAs(relation, 'predicate', parent)},
            icon: Text('P')),
        IconButton.filledTonal(
            onPressed: () => {labelState.mergeAs(relation, 'object', parent)},
            icon: Text('O')),
        IconButton.filledTonal(
            onPressed: () => {labelState.delete(relation, parent)},
            icon: Icon(Icons.delete_forever)),
      ]);
    }

    return Container(
      margin: const EdgeInsets.all(2.0),
      padding: const EdgeInsets.all(2.0),
      decoration: parent != null
          ? BoxDecoration(border: Border.all(color: Colors.black))
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        // spacing: 2,
        children: [
          Wrap(
              // alignment: WrapAlignment.center,
              // runAlignment: WrapAlignment.center,
              spacing: 10,
              children: elementChildren),
          Wrap(
              // alignment: WrapAlignment.center,
              // runAlignment: WrapAlignment.center,
              children: mergeChildren)
        ],
      ),
    );
  }
}
