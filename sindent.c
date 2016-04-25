#include <stdio.h>

int main() {
  char c;
  int level = -1;
  while((c = getchar()) != EOF) {
    if (c == '(') {
      putchar('\n');
      level++;
    }
    if (c == ')' || c == ']' || c == '}') {
      level--;
    }
    if (c == '(' || c == '\n') {
      for (int i = 0; i < level; i++) {
        putchar(' ');
        putchar(' ');
      }
    }
    putchar(c);
  }
}
