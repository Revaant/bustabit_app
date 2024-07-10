import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfitData extends ChangeNotifier {
  double highWaterMark = 0.0;
  double currentProfit = 0.0;
  bool notified = false;

  ProfitData() {
    loadHighWaterMark();
  }

  Future<void> loadHighWaterMark() async {
    final prefs = await SharedPreferences.getInstance();
    highWaterMark = prefs.getDouble('highWaterMark') ?? 0.0;
    notifyListeners();
  }

  Future<void> saveHighWaterMark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('highWaterMark', highWaterMark);
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse('https://dicesites.com/bustabit'));
      if (response.statusCode == 200) {
        final content = response.body;
        final regex = RegExp(r'Profit:\s*<span class="right green">\s*([0-9.,]+)\s*BTC</span>');
        final match = regex.firstMatch(content);
        if (match != null) {
          currentProfit = double.parse(match.group(1)!.replaceAll(',', ''));
          if (currentProfit > highWaterMark) {
            highWaterMark = currentProfit;
            notified = false;
            await saveHighWaterMark();
          }
          checkAlerts(); // Always check alerts after updating current profit
          notifyListeners();
        } else {
          print('Total profit not found in the HTML content');
        }
      } else {
        print('Failed to load data');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  void checkAlerts() {
    final dropPercent = ((highWaterMark - currentProfit) / highWaterMark) * 100;
    if (dropPercent > 0 && !notified) {
      sendAlert(dropPercent);
    }
    sendAlert(dropPercent);
  }

  void sendAlert(double dropPercent) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channelId', 'channelName', 'channelDescription',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = IOSNotificationDetails();

    const NotificationDetails generalnotificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    flutterLocalNotificationsPlugin.show(
      0,
      'Bustabit Profit Alert',
      'Alert: Total profit is down ${dropPercent.toStringAsFixed(6)}% from the high water mark.',
      generalnotificationDetails,
    );

    notified = true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfitData(),
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Bustabit Profit Monitor 🦖💰')),
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tanius.png'),  // Adjust the path accordingly
                fit: BoxFit.cover,  // Or use BoxFit.fill, BoxFit.fitWidth, etc.
              ),
            ),
            child: const ProfitMonitor(),
          ),
        ),
      ),
    );
  }
}

class ProfitMonitor extends StatefulWidget {
  const ProfitMonitor({super.key});

  @override
  _ProfitMonitorState createState() => _ProfitMonitorState();
}

class _ProfitMonitorState extends State<ProfitMonitor> {
  @override
  void initState() {
    super.initState();
    fetchDataPeriodically();
  }

  void fetchDataPeriodically() {
    final profitData = Provider.of<ProfitData>(context, listen: false);
    profitData.fetchData();
    Future.delayed(const Duration(seconds: 5), fetchDataPeriodically); // Fetch data every 5 seconds
  }

  @override
  Widget build(BuildContext context) {
    final profitData = Provider.of<ProfitData>(context);
    final dropPercent = ((profitData.highWaterMark - profitData.currentProfit) / profitData.highWaterMark) * 100;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              'High Water Mark: ${profitData.highWaterMark.toStringAsFixed(2)} BTC',
              style: const TextStyle(
                fontSize: 30,  // Adjust the font size as needed
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Current Profit: ${profitData.currentProfit.toStringAsFixed(2)} BTC',
              style: const TextStyle(
                fontSize: 30,  // Adjust the font size as needed
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Drop Percent: ${dropPercent.toStringAsFixed(6)}%',
              style: const TextStyle(
                fontSize: 30,  // Adjust the font size as needed
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const initializationSettingsAndroid = AndroidInitializationSettings('app_icon');

  const initializationSettingsIOS = IOSInitializationSettings();

  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}
