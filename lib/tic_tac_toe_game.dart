import 'package:flutter/material.dart';

void main() {
  runApp(TicTacToeApp());
}

class TicTacToeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TicTacToeGame(),
    );
  }
}

class TicTacToeGame extends StatefulWidget {
  @override
  _TicTacToeGameState createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  List<String> board = List.generate(9, (index) => '');
  bool isXTurn = true;
  String winner = '';

  void _handleTap(int index) {
    if (board[index] == '' && winner == '') {
      setState(() {
        board[index] = isXTurn ? 'X' : 'O';
        isXTurn = !isXTurn;
        _checkWinner();
      });
    }
  }

  void _checkWinner() {
    List<List<int>> winningCombinations = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
      [0, 4, 8], [2, 4, 6] // Diagonals
    ];

    for (var combo in winningCombinations) {
      String a = board[combo[0]], b = board[combo[1]], c = board[combo[2]];
      if (a == b && b == c && a != '') {
        setState(() {
          winner = a;
        });
        return;
      }
    }

    if (!board.contains('')) {
      setState(() {
        winner = 'Draw';
      });
    }
  }

  void _resetGame() {
    setState(() {
      board = List.generate(9, (index) => '');
      isXTurn = true;
      winner = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1117), // Dark background
      appBar: AppBar(
        title: Text("Tic Tac Toe"),
        backgroundColor: Colors.blueGrey[800],
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            winner.isEmpty ? "Turn: ${isXTurn ? 'X' : 'O'}" : "Winner: $winner",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.redAccent, blurRadius: 10),
                Shadow(color: Colors.yellowAccent, blurRadius: 10),
              ],
            ),
          ),
          SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _handleTap(index),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: board[index] == ''
                        ? Color(0xFF1E1E1E) // Empty cell
                        : (board[index] == 'X'
                            ? Colors.redAccent
                            : Colors.yellowAccent),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: board[index] == 'X'
                            ? Colors.redAccent
                            : Colors.yellowAccent,
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      child: Text(
                        board[index],
                        key: ValueKey(board[index]),
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          color:
                              board[index] == 'X' ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _resetGame,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: Colors.orangeAccent,
              textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            child: Text("Restart Game"),
          ),
        ],
      ),
    );
  }
}
