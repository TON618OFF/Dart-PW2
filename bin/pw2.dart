import 'dart:io';
import 'dart:math';

enum Cell { empty, ship, hit, miss }

class Ship {
  final String name;
  final int size;
  List<Point<int>> coords = [];
  Set<Point<int>> hits = {};

  Ship(this.name, this.size);

  bool isSunk() => hits.length >= size;
  bool occupies(Point<int> p) => coords.contains(p);
  void registerHit(Point<int> p) {
    if (occupies(p)) hits.add(p);
  }
}

class Board {
  final int rows;
  final int cols;
  late List<List<Cell>> grid;
  List<Ship> ships = [];

  Board(this.rows, this.cols) {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => Cell.empty));
  }

  bool inBounds(Point<int> p) =>
      p.x >= 0 && p.x < rows && p.y >= 0 && p.y < cols;

  bool canPlaceShip(Point<int> start, bool horizontal, int size) {
    for (int i = 0; i < size; i++) {
      final p = horizontal
          ? Point(start.x, start.y + i)
          : Point(start.x + i, start.y);
      if (!inBounds(p)) return false;
      if (grid[p.x][p.y] != Cell.empty) return false;
      // check adjacent cells to disallow touching (optional, but nicer)
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final np = Point(p.x + dx, p.y + dy);
          if (inBounds(np) && grid[np.x][np.y] == Cell.ship) return false;
        }
      }
    }
    return true;
  }

  bool placeShip(Ship ship, Point<int> start, bool horizontal) {
    if (!canPlaceShip(start, horizontal, ship.size)) return false;
    for (int i = 0; i < ship.size; i++) {
      final p = horizontal
          ? Point(start.x, start.y + i)
          : Point(start.x + i, start.y);
      grid[p.x][p.y] = Cell.ship;
      ship.coords.add(p);
    }
    ships.add(ship);
    return true;
  }

  String displayOwn() {
    // показываем свои корабли + попадания/мимо
    final sb = StringBuffer();
    sb.writeln(
      '   ' + List.generate(cols, (i) => i.toString().padLeft(2)).join(' '),
    );
    for (int r = 0; r < rows; r++) {
      sb.write(r.toString().padLeft(2) + ' ');
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        String ch;
        switch (cell) {
          case Cell.empty:
            ch = '.';
            break;
          case Cell.ship:
            ch = 'S';
            break;
          case Cell.hit:
            ch = 'X';
            break;
          case Cell.miss:
            ch = 'o';
            break;
        }
        sb.write(ch.padLeft(2) + ' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  String displayForOpponent() {
    // показываем только попадания и промахи — скрываем корабли
    final sb = StringBuffer();
    sb.writeln(
      '   ' + List.generate(cols, (i) => i.toString().padLeft(2)).join(' '),
    );
    for (int r = 0; r < rows; r++) {
      sb.write(r.toString().padLeft(2) + ' ');
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        String ch;
        switch (cell) {
          case Cell.hit:
            ch = 'X';
            break;
          case Cell.miss:
            ch = 'o';
            break;
          default:
            ch = '.';
            break;
        }
        sb.write(ch.padLeft(2) + ' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  bool receiveShot(Point<int> p) {
    if (!inBounds(p)) return false;
    if (grid[p.x][p.y] == Cell.hit || grid[p.x][p.y] == Cell.miss) {
      // already shot
      return false;
    }
    if (grid[p.x][p.y] == Cell.ship) {
      grid[p.x][p.y] = Cell.hit;
      for (var s in ships) {
        if (s.occupies(p)) {
          s.registerHit(p);
          break;
        }
      }
      return true;
    } else {
      grid[p.x][p.y] = Cell.miss;
      return false;
    }
  }

  bool allShipsSunk() => ships.every((s) => s.isSunk());
}

abstract class Player {
  final String name;
  final Board board;
  Player(this.name, this.board);

  Future<void> placeShips(List<Ship> ships);
  Future<Point<int>?> chooseShot(Board opponentBoard);
}

class HumanPlayer extends Player {
  HumanPlayer(String name, Board board) : super(name, board);

  @override
  Future<void> placeShips(List<Ship> ships) async {
    print(
      'Игрок "$name", расставьте корабли на поле ${board.rows}x${board.cols}.',
    );
    print(
      'Координаты вводите как: строка,столбец (например: 0,3). Ориентация H или V.',
    );
    for (var ship in ships) {
      bool placed = false;
      while (!placed) {
        print('');
        print('Текущее поле:');
        print(board.displayOwn());
        stdout.write(
          'Поставьте корабль "${ship.name}" (длина ${ship.size}). Введите start (r,c) и ориентацию H/V через пробел: ',
        );
        final line = stdin.readLineSync();
        if (line == null) continue;
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 2) {
          print('Неверный формат. Попробуйте снова.');
          continue;
        }
        final coord = parts[0].split(',');
        if (coord.length != 2) {
          print('Неверные координаты. Попробуйте снова.');
          continue;
        }
        final r = int.tryParse(coord[0]);
        final c = int.tryParse(coord[1]);
        if (r == null || c == null) {
          print('Неверные числа. Попробуйте снова.');
          continue;
        }
        final ori = parts[1].toUpperCase();
        final horizontal = ori.startsWith('H');
        final shipCopy = Ship(ship.name, ship.size);
        final success = board.placeShip(shipCopy, Point(r, c), horizontal);
        if (!success) {
          print('Нельзя поставить корабль в эту позицию. Попробуйте ещё раз.');
        } else {
          print('Корабль поставлен.');
          placed = true;
        }
      }
      _pauseForSwitch();
    }
  }

  @override
  Future<Point<int>?> chooseShot(Board opponentBoard) async {
    while (true) {
      stdout.write('Введите координаты выстрела (r,c) или "q" для выхода: ');
      final line = stdin.readLineSync();
      if (line == null) continue;
      if (line.trim().toLowerCase() == 'q') return null;
      final coord = line.split(',');
      if (coord.length != 2) {
        print('Неверный формат. Повторите ввод.');
        continue;
      }
      final r = int.tryParse(coord[0]);
      final c = int.tryParse(coord[1]);
      if (r == null || c == null) {
        print('Неверные числа. Повторите ввод.');
        continue;
      }
      final p = Point<int>(r, c);
      if (!opponentBoard.inBounds(p)) {
        print('Вне поля. Повторите ввод.');
        continue;
      }
      final cell = opponentBoard.grid[p.x][p.y];
      if (cell == Cell.hit || cell == Cell.miss) {
        print('Уже стреляли в эту клетку. Выберите другую.');
        continue;
      }
      return p;
    }
  }

  void _pauseForSwitch() {
    // небольшая пауза и очистка консоли, чтобы другой игрок не подсмотрел
    stdout.writeln('Нажмите Enter чтобы продолжить...');
    stdin.readLineSync();
    clearConsole();
  }
}

class BotPlayer extends Player {
  final Random _rand = Random();
  List<Point<int>> _possibleShots = [];
  // simple hunting memory
  Point<int>? _lastHit;
  List<Point<int>> _huntQueue = [];

  BotPlayer(String name, Board board) : super(name, board) {
    // fill possible shots later when board size known
  }

  @override
  Future<void> placeShips(List<Ship> ships) async {
    for (var ship in ships) {
      bool placed = false;
      int tries = 0;
      while (!placed && tries < 1000) {
        final horizontal = _rand.nextBool();
        final r = _rand.nextInt(board.rows);
        final c = _rand.nextInt(board.cols);
        final shipCopy = Ship(ship.name, ship.size);
        placed = board.placeShip(shipCopy, Point(r, c), horizontal);
        tries++;
      }
      if (!placed) {
        // если не получилось через много попыток — очищаем и начинаем заново
        board.grid = List.generate(
          board.rows,
          (_) => List.generate(board.cols, (_) => Cell.empty),
        );
        board.ships.clear();
        await placeShips(ships);
        return;
      }
    }
    // подготовить список возможных выстрелов
    _possibleShots = [];
    for (int r = 0; r < board.rows; r++) {
      for (int c = 0; c < board.cols; c++) {
        _possibleShots.add(Point(r, c));
      }
    }
  }

  @override
  Future<Point<int>?> chooseShot(Board opponentBoard) async {
    // если есть клетки в huntQueue — используем их
    if (_huntQueue.isNotEmpty) {
      final p = _huntQueue.removeAt(0);
      if (opponentBoard.inBounds(p)) {
        final cell = opponentBoard.grid[p.x][p.y];
        if (cell != Cell.hit && cell != Cell.miss) {
          _possibleShots.removeWhere((x) => x == p);
          return p;
        }
      }
    }
    // иначе, случайный выбор из возможных
    if (_possibleShots.isEmpty) return null;
    final idx = _rand.nextInt(_possibleShots.length);
    final p = _possibleShots.removeAt(idx);
    return p;
  }

  void processShotResult(Point<int> shot, bool wasHit, Board opponentBoard) {
    if (wasHit) {
      // добавить соседние клетки в охоту
      final neighbors = [
        Point(shot.x - 1, shot.y),
        Point(shot.x + 1, shot.y),
        Point(shot.x, shot.y - 1),
        Point(shot.x, shot.y + 1),
      ];
      for (var n in neighbors) {
        if (opponentBoard.inBounds(n)) {
          final cell = opponentBoard.grid[n.x][n.y];
          if (cell != Cell.hit && cell != Cell.miss) {
            if (!_huntQueue.contains(n)) _huntQueue.add(n);
          }
        }
      }
    }
  }
}

void clearConsole() {
  // ANSI escape sequence - очищает экран в большинстве терминалов
  stdout.write('\x1B[2J\x1B[0;0H');
}

List<Ship> shipsForSize(int size) {
  // возвращаем список кораблей в зависимости от размера поля
  // простая логика: для 8x8 — меньше кораблей, для 12x12 — больше
  if (size <= 8) {
    return [
      Ship('Линкор', 4),
      Ship('Крейсер', 3),
      Ship('Эсминец', 2),
      Ship('Подлодка', 1),
    ];
  } else if (size <= 10) {
    return [
      Ship('Линкор', 4),
      Ship('Крейсер', 3),
      Ship('Крейсер2', 3),
      Ship('Эсминец', 2),
      Ship('Эсминец2', 2),
      Ship('Подлодка', 1),
      Ship('Подлодка2', 1),
    ];
  } else {
    return [
      Ship('Линкор', 5),
      Ship('Крейсер', 4),
      Ship('Крейсер2', 3),
      Ship('Эсминец', 2),
      Ship('Эсминец2', 2),
      Ship('Подлодка', 1),
      Ship('Подлодка2', 1),
      Ship('Подлодка3', 1),
    ];
  }
}

Future<void> twoPlayerGame(bool vsBot) async {
  clearConsole();
  print('=== Морской бой ===');
  stdout.write('Введите имя первого игрока: ');
  final name1 = stdin.readLineSync()!.trim();
  String name2;
  if (vsBot) {
    name2 = 'Бот';
    print('Вы играете против бота.');
  } else {
    stdout.write('Введите имя второго игрока: ');
    name2 = stdin.readLineSync()!.trim();
  }

  // выбор размера поля (3 варианта)
  print('Выберите размер поля:');
  final options = {'1': 8, '2': 10, '3': 12};
  print('1) 8 x 8');
  print('2) 10 x 10');
  print('3) 12 x 12');
  int chosenSize = 10;
  while (true) {
    stdout.write('Ввод (1-3): ');
    final pick = stdin.readLineSync();
    if (pick != null && options.containsKey(pick.trim())) {
      chosenSize = options[pick.trim()]!;
      break;
    }
    print('Неверно. Попробуйте снова.');
  }

  final ships = shipsForSize(chosenSize);

  final board1 = Board(chosenSize, chosenSize);
  final board2 = Board(chosenSize, chosenSize);

  final player1 = HumanPlayer(name1, board1);
  Player player2;
  if (vsBot) {
    player2 = BotPlayer(name2, board2);
  } else {
    player2 = HumanPlayer(name2, board2);
  }

  // Расстановка кораблей
  clearConsole();
  print('Игрок ${player1.name} будет расставлять свои корабли.');
  await player1.placeShips(ships.map((s) => Ship(s.name, s.size)).toList());
  clearConsole();
  if (vsBot) {
    print('Бот расставляет свои корабли...');
    await player2.placeShips(ships.map((s) => Ship(s.name, s.size)).toList());
    // не показываем поле бота
  } else {
    print('Игрок ${player2.name} теперь расставляет свои корабли.');
    await player2.placeShips(ships.map((s) => Ship(s.name, s.size)).toList());
  }

  // Игра по очереди
  Player current = player1;
  Player other = player2;
  BotPlayer? bot = player2 is BotPlayer
      ? player2 as BotPlayer
      : (player1 is BotPlayer ? player1 as BotPlayer : null);
  while (true) {
    clearConsole();
    print('Теперь ходит: ${current.name}');
    print('');
    // показываем поля: своё и поле соперника (скрытое)
    print('Ваше поле:');
    print(current.board.displayOwn());
    print('Поле противника (показаны только попадания и промахи):');
    print(other.board.displayForOpponent());

    Point<int>? shot;
    if (current is HumanPlayer) {
      shot = await current.chooseShot(other.board);
      if (shot == null) {
        print('Игрок сдался. Игра окончена.');
        return;
      }
    } else if (current is BotPlayer) {
      shot = await current.chooseShot(other.board);
      // небольшая задержка для реалистичности
      sleep(Duration(milliseconds: 300));
      print('${current.name} стреляет в ${shot!.x},${shot.y}');
    }

    if (shot == null) break;

    final wasHit = other.board.receiveShot(shot);
    if (current is BotPlayer && bot != null) {
      // если бот стреляет по человеку, не надо скрывать — но это внутренняя логика
      bot.processShotResult(shot, wasHit, other.board);
    }

    if (wasHit) {
      print('Попадание!');
      // узнаем, потонул ли корабль
      for (var s in other.board.ships) {
        if (s.occupies(shot)) {
          if (s.isSunk()) {
            print('Корабль "${s.name}" потоплен!');
          }
          break;
        }
      }
    } else {
      print('Мимо.');
    }

    // Проверка победы
    if (other.board.allShipsSunk()) {
      print('');
      print('Игрок ${current.name} победил! Все корабли противника потоплены.');
      // показываем поля финально (если против бот — всё равно не показываем расположение кораблей бота по условию)
      print('Финальное состояние поля победителя:');
      print(current.board.displayOwn());
      break;
    }

    // Смена игроков
    print('');
    print('Нажмите Enter, чтобы передать ход другому игроку...');
    stdin.readLineSync();

    // если следующий — человек, очистим консоль для предотвращения подглядывания
    current = other;
    other = (current == player1) ? player2 : player1;
    clearConsole();
  }
}

void main() async {
  clearConsole();
  print('=== Морской бой (консоль) ===');
  print('Выберите режим:');
  print('1) 2 игрока (по очереди)');
  print('2) Игрок против бота');
  stdout.write('Выбор (1/2): ');
  final choice = stdin.readLineSync();
  if (choice == '1') {
    await twoPlayerGame(false);
  } else {
    await twoPlayerGame(true);
  }
  print('Спасибо за игру!');
}
