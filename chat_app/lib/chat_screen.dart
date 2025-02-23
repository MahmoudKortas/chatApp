import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? userName = 'u4';
  String? receiverName = 'u3';
  late WebSocketChannel channel;
  TextEditingController messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(Uri.parse("ws://localhost:5000?sender=$userName&receiver=$receiverName"));
    channel.stream.listen((data) {
      var decodedData = jsonDecode(data);
      if (decodedData["type"] == "history") {
        // Load chat history
        setState(() {
          messages = List<Map<String, dynamic>>.from(decodedData["messages"]);
        });
      } else if (decodedData["type"] == "message") {
        // Receive new messages
        setState(() {
          messages.add(decodedData["message"]);
        });
      }
    });

    // fetchChatHistory();
  }

  Future<void> fetchChatHistory() async {
    final response = await http.get(
      Uri.parse(
        'http://127.0.0.1:5000/messages?sender=$userName&receiver=$receiverName',
      ),
    );

    if (response.statusCode == 200) {
      log('Response_body::${response.body}');
      setState(() {
        messages = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }

  void sendMessage() {
    if (messageController.text.isNotEmpty) {
      log('Sending_message::${messageController.text}');
      final messageData = {
        "sender": userName,
        "receiver": receiverName,
        "message": messageController.text.trim(),
      };
      channel.sink.add(jsonEncode(messageData));
      // messageController.clear();
    }
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with $receiverName")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                bool isMe = messages[index]["sender"] == userName;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      messages[index]["message"],
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(hintText: "Type a message..."),
                  ),
                ),
                IconButton(icon: Icon(Icons.send), onPressed: sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
