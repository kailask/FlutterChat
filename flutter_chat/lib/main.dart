import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
Firestore fire = Firestore.instance;
SharedPreferences prefs;

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  MyApp() {
    fire.settings(timestampsInSnapshotsEnabled: true);
    _firebaseMessaging.requestNotificationPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Chat"), centerTitle: true),
        body: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (BuildContext context,
              AsyncSnapshot<SharedPreferences> snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return new Center(
                  child: CircularProgressIndicator(),
                );
              default:
                if (!snapshot.hasError) {
                  prefs = snapshot.data;
                  return prefs.getString("user") != null
                      ? new ChatScreen()
                      : new LoginScreen();
                } else {
                  return new Text(snapshot.error);
                }
            }
          },
        ),
      ),
      theme: ThemeData(primarySwatch: Colors.deepOrange),
    );
  }
}

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.deepOrange,
        alignment: Alignment.center,
        padding: EdgeInsets.all(50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter name:",
              style: TextStyle(fontSize: 25, color: Colors.white),
            ),
            TextField(
              autofocus: true,
              cursorColor: Colors.white,
              style: TextStyle(fontSize: 20, color: Colors.white),
              decoration: null,
              onSubmitted: _onSubmit,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
            ),
          ],
        ));
  }

  void _onSubmit(String name) async {
    await prefs.setString("user", name);
    runApp(new MyApp());
  }
}

class ChatScreen extends StatelessWidget {
  final TextEditingController t = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Chat(),
        ),
        Divider(
          height: 0,
        ),
        _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    return Row(
      children: [
        Expanded(
          child: Padding(
              padding: EdgeInsets.only(left: 5, right: 5),
              child: TextField(
                onSubmitted: _onSubmit,
                controller: t,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                autocorrect: true,
                style: TextStyle(color: Colors.black, fontSize: 20),
              )),
        )
      ],
    );
  }

  void _onSubmit(String txt) {
    fire.collection("chat").add(
        {"user": prefs.getString("user"), "msg": txt, "time": Timestamp.now()});
    t.clear();
  }
}

class Chat extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ChatState();
  }
}

class ChatState extends State<Chat> {
  bool allCached = false;
  static const int loadLimit = 20;
  static final cache = <Message>[];
  static final Query loadQuery = fire
      .collection("chat")
      .orderBy("time", descending: true)
      .limit(loadLimit);
  static var subscription;
  ListView list;

  @override
  Widget build(BuildContext context) {
    return list = ListView.builder(
      reverse: true,
      itemCount: (allCached) ? cache.length : cache.length + 1,
      controller: ScrollController(), //TODO: Control scrolling on new message
      itemBuilder: (context, i) {
        if (i < cache.length) return _buildItem(i);

        if (cache.length > 0)
          loadQuery
              .startAfter([cache.last.time])
              .getDocuments()
              .then(loadOlder);
        else
          loadQuery.getDocuments().then(loadOlder);

        return LinearProgressIndicator();
      },
    );
  }

  Widget _buildItem(int index) {
    Message msg =cache[index];
    
    bool alignSent = msg.user == prefs.getString("user");
    return ListTile(
      title: Card(
        child: Padding(
          child: Text(msg.msg,style: TextStyle(color: alignSent?Colors.white:Colors.black),),
          padding: EdgeInsets.all(10),
        ),
        margin: EdgeInsets.only(left: alignSent?80:0,right: alignSent?0:80,bottom: 5),
        color: alignSent?Colors.deepOrangeAccent:Colors.white,
      ),
      subtitle: Text(msg.user,textAlign: alignSent?TextAlign.right:TextAlign.left,),
    );
  }

  void loadOlder(QuerySnapshot snapshot) {
    allCached = snapshot.documents.length < loadLimit;

    for (var item in snapshot.documents) {
      cache
          .add(Message(item.data['user'], item.data['msg'], item.data['time']));
    }

    if (subscription == null) {
      if (cache.length > 0)
        subscription = fire
            .collection("chat")
            .where("time", isGreaterThan: cache.first.time)
            .snapshots()
            .listen(loadNewer);
      else
        subscription = fire.collection("chat").snapshots().listen(loadNewer);
    }

    setState(() {});
  }

  void loadNewer(s) {
    s.documentChanges.forEach((f) {
      var data = f.document.data;
      cache.insert(0, Message(data['user'], data['msg'], data['time']));
    });

    setState(() {});
  }
}

class Message {
  final String user;
  final String msg;
  final Timestamp time;

  Message(this.user, this.msg, this.time);
}
