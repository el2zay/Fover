import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyCheckboxListTile extends StatefulWidget {
  final Text title;
  final String? subtitle;
  final bool value;
  final void Function(bool?) onChanged;


  const MyCheckboxListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged
  });

  @override
  State<MyCheckboxListTile> createState() => _MyCheckboxListTileState();
}

class _MyCheckboxListTileState extends State<MyCheckboxListTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: widget.title,
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      trailing: widget.value 
        ? Icon(CupertinoIcons.check_mark_circled_solid, color: Theme.of(context).primaryColor)
        : null,
      onTap: () => widget.onChanged(!widget.value),
    );
  }
}