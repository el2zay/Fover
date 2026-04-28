import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:intl/intl.dart';

class AdjustDate extends StatefulWidget {
  final String encodedPath;
  final PhotoEntry photo;
  final DateTime initialDate;
  
  const AdjustDate({super.key, required this.encodedPath, required this.photo, required this.initialDate});

  @override
  State<AdjustDate> createState() => _AdjustDateState();
}

class _AdjustDateState extends State<AdjustDate> {
  DateTime? newDate;
  late final DateTime? _originalDisplayDate;

  @override
  void initState() {
    super.initState();
    _originalDisplayDate = widget.photo.displayDate;
  }

  DateTime get localNewDate => newDate ?? PhotoStore.getDate(widget.encodedPath);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: Transform.scale(
          scale: 0.8,
          child: Button.iconOnly(
            icon: Icon(Icons.close),
            glassIcon: CNSymbol('xmark', size: 16),
            backgroundColor: Colors.transparent,
            onPressed: () => Navigator.pop(context)
          ),
        ),
        title: Text("Adjust the time and date", style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
        actions: [
          Button(
            label: "Adjust",
            glassConfig: const CNButtonConfig(
              style: CNButtonStyle.prominentGlass,
            ),
            textColor: Colors.blue,
            tint: Colors.blue.withAlpha(230),
            onPressed: () {
              if (newDate != null) {
                final isReverted = newDate == widget.photo.date && _originalDisplayDate == null;
                if (isReverted) {
                  PhotoStore.update(path: widget.encodedPath, clearDisplayDate: true);
                } else {
                  PhotoStore.update(path: widget.encodedPath, displayDate: newDate!);
                }
              }
              Navigator.pop(context);
            }
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(10),
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(20)
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Original", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                      DateFormat('d MMMM yyyy — hh:mm', 'en').format(widget.initialDate),
                      style: TextStyle(
                        fontSize: 14, 
                        color: Theme.of(context).primaryColor.withAlpha(150)
                      )
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Divider(color: Colors.white12),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Adjusted", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                      DateFormat('d MMMM yyyy — hh:mm', 'en').format(localNewDate),
                      style: TextStyle(fontSize: 14)
                    ),
                  ],
                ),
              ],
            )
          ),
          SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(20)
            ),
            padding: EdgeInsets.only(bottom: 10),
            width: MediaQuery.of(context).size.width * 0.8,
            child: CupertinoCalendar(
              use24hFormat: true,
              minimumDateTime: DateTime(0), 
              maximumDateTime: DateTime(9999),
              initialDateTime: PhotoStore.getDate(widget.encodedPath),
              mainColor: CupertinoColors.activeBlue,
              mode: CupertinoCalendarMode.dateTime,
              timeLabel: "Time",
              onDateTimeChanged: (date) {
                setState(() => newDate = date);
              }
            ),
          )
        ],
      ),
    );
  }
}