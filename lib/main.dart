import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://bahltyloeukzspyxdaxh.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhaGx0eWxvZXVrenNweXhkYXhoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4MTQ4ODcsImV4cCI6MjA4NDM5MDg4N30.IPTRHuRxeg3JHB3AssJuhCCzP2JSA2bcAXvVG_3lMy4';

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const ProviderScope(child: MangialoquiMenuApp()));
}
