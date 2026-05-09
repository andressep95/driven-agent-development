package com.cloudcentinel.setup;

import org.jline.terminal.Attributes;
import org.jline.terminal.Terminal;
import org.jline.terminal.TerminalBuilder;

import java.io.PrintWriter;
import java.util.*;

public final class Checklist {

    private Checklist() {}

    public static Set<String> select(String title, String[] labels, String[] keys, boolean[] defaults) throws Exception {
        boolean[] marked = Arrays.copyOf(defaults, defaults.length);
        int cursor = 0;

        try (Terminal terminal = TerminalBuilder.builder().system(true).build()) {
            Attributes saved = terminal.enterRawMode();
            PrintWriter out = terminal.writer();
            try {
                render(out, title, labels, marked, cursor);
                while (true) {
                    int ch = terminal.reader().read();
                    if (ch == 27) {
                        int b = terminal.reader().read();
                        if (b == '[') {
                            int dir = terminal.reader().read();
                            if      (dir == 'A' && cursor > 0)                cursor--;
                            else if (dir == 'B' && cursor < labels.length - 1) cursor++;
                        }
                    } else if (ch == ' ') {
                        marked[cursor] = !marked[cursor];
                    } else if (ch == 'a' || ch == 'A') {
                        boolean anyOn = false;
                        for (boolean m : marked) if (m) { anyOn = true; break; }
                        Arrays.fill(marked, !anyOn);
                    } else if (ch == '\r' || ch == '\n') {
                        break;
                    }
                    clearLines(out, labels.length + 3);
                    render(out, title, labels, marked, cursor);
                }
            } finally {
                terminal.setAttributes(saved);
                out.print("\r\n");
                out.flush();
            }
        }

        Set<String> result = new LinkedHashSet<>();
        for (int i = 0; i < keys.length; i++) {
            if (marked[i]) result.add(keys[i]);
        }
        return result;
    }

    // \r\n required in raw mode — plain \n is LF-only and drifts the cursor rightward
    private static void render(PrintWriter out, String title, String[] labels, boolean[] marked, int cursor) {
        out.print(title + "\r\n");
        out.print("  ↑↓ navigate  ·  Space toggle  ·  A all/none  ·  Enter confirm\r\n\r\n");
        for (int i = 0; i < labels.length; i++) {
            String pointer = i == cursor ? "> " : "  ";
            String check   = marked[i]   ? "x" : " ";
            out.printf("  %s[%s] %s\r\n", pointer, check, labels[i]);
        }
        out.flush();
    }

    private static void clearLines(PrintWriter out, int n) {
        for (int i = 0; i < n; i++) out.print("\033[1A\033[2K");
        out.flush();
    }
}
