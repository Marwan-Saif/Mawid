import 'package:equatable/equatable.dart';

import 'desk_board.dart';

class DisplayStaff extends Equatable {
  const DisplayStaff({
    required this.id,
    required this.name,
    required this.titleAr,
    required this.titleEn,
    required this.presence,
    this.room,
    this.nowServingTicket,
    this.nowServingName,
  });

  final String id;
  final String name;
  final String titleAr;
  final String titleEn;
  final String? room;
  final StaffPresence presence;
  final int? nowServingTicket;
  final String? nowServingName;

  @override
  List<Object?> get props => [id, presence, nowServingTicket];
}

class DisplayEntry extends Equatable {
  const DisplayEntry({
    required this.ticketNo,
    required this.name,
    required this.etaMin,
    required this.delayMin,
    this.staffName,
    this.room,
  });

  final int ticketNo;

  /// Shortened for a public screen: "مريم ع.", "أبو سامي".
  final String name;
  final String? staffName;
  final String? room;
  final int etaMin;
  final int delayMin;

  @override
  List<Object?> get props => [ticketNo, name, etaMin, delayMin];
}

/// The latest call to the room. [seq] changes on every call and repeat, which is when to speak.
class DisplayCall extends Equatable {
  const DisplayCall({required this.seq, required this.ticketNo, required this.name, required this.at, this.room, this.staffName});

  final String seq;
  final int ticketNo;
  final String name;
  final String? room;
  final String? staffName;
  final DateTime at;

  @override
  List<Object?> get props => [seq];
}

class WaitingDisplay extends Equatable {
  const WaitingDisplay({
    required this.place,
    required this.staff,
    required this.waiting,
    required this.servedToday,
    required this.serverTime,
    this.lastCall,
  });

  final DeskPlace place;
  final List<DisplayStaff> staff;
  final List<DisplayEntry> waiting;
  final DisplayCall? lastCall;
  final int servedToday;
  final DateTime serverTime;

  @override
  List<Object?> get props => [place, staff, waiting, lastCall, servedToday];
}
