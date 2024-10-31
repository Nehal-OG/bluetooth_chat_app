import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class ChatScreen extends StatefulWidget {
  final BluetoothDevice device;
  const ChatScreen({super.key, required this.device});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  BluetoothCharacteristic? chatCharacteristic; // Changed to nullable
  bool isConnected = false;
  final TextEditingController messageController = TextEditingController();
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    widget.device.state.listen((connectionState) {
      if (connectionState == BluetoothDeviceState.disconnected) {
        setState(() {
          isConnected = false;
        });
        // Optionally, show a message or reconnect
        log("Device disconnected");
      }
    });
  }

  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      log("Connected to device: ${widget.device.name}");

      // Discover services and characteristics
      var services = await widget.device.discoverServices();
      log("Services discovered: $services");

      // Replace with the UUID of your Bluetooth characteristic
      const characteristicUUID = "YOUR_CHARACTERISTIC_UUID";

      bool characteristicFound = false; // Track if characteristic is found

      for (var service in services) {
        log("Service: ${service.uuid}");
        for (var characteristic in service.characteristics) {
          log("Characteristic: ${characteristic.uuid}");
          if (characteristic.uuid.toString() == characteristicUUID) {
            chatCharacteristic = characteristic;
            characteristicFound = true; // Set to true if found
            setState(() {
              isConnected = true;
            });
            log("Chat characteristic found: ${chatCharacteristic!.uuid}");
            _startListeningForMessages();
            return; // Exit after finding the characteristic
          }
        }
      }

      // Log if characteristic is not found
      if (!characteristicFound) {
        log("Chat characteristic not found for UUID: $characteristicUUID");
      }
    } catch (e) {
      log("Error connecting to device: $e");
    }
  }

  void _startListeningForMessages() {
    // Check if chatCharacteristic is initialized
    if (chatCharacteristic != null) {
      chatCharacteristic!.value.listen((value) {
        String receivedMessage = utf8.decode(value);
        setState(() {
          messages.add("Device: $receivedMessage");
        });
      });
    } else {
      log("Chat characteristic not initialized");
    }
  }

  void _sendMessage() {
    if (messageController.text.isNotEmpty && chatCharacteristic != null) {
      chatCharacteristic!.write(utf8.encode(messageController.text));
      setState(() {
        messages.add("You: ${messageController.text}");
        messageController.clear();
      });
    } else if (chatCharacteristic == null) {
      log("Chat characteristic is not initialized. Cannot send message.");
      // Optionally show an alert or a Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Cannot send message: characteristic not initialized")),
      );
    }
  }

  @override
  void dispose() {
    if (isConnected) {
      widget.device.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with ${widget.device.name}")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(hintText: "Type a message"),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
