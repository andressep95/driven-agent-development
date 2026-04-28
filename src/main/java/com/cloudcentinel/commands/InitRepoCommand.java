package com.cloudcentinel.commands;

import picocli.CommandLine.Command;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.List;
import java.util.Scanner;
import java.util.concurrent.Callable;

@Command(
    name = "init-repo",
    description = "Verifica si existe un repositorio git activo. Si no existe, ofrece inicializarlo.",
    mixinStandardHelpOptions = true
)
public class InitRepoCommand implements Callable<Integer> {

    @Override
    public Integer call() {
        if (isGitRepo()) {
            System.out.println("Repositorio git activo detectado en el directorio actual.");
            return 0;
        }

        System.out.print("No hay repositorio inicializado en este fichero.\n"
                + "¿Desea iniciar uno? [s/n]: ");

        String respuesta = new Scanner(System.in).nextLine().trim().toLowerCase();

        if (!respuesta.equals("s")) {
            System.out.println("Operación cancelada.");
            return 0;
        }

        return initRepo();
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private boolean isGitRepo() {
        List<String> out = run(List.of("git", "rev-parse", "--git-dir"));
        return !out.isEmpty() && !out.get(0).startsWith("fatal:");
    }

    private int initRepo() {
        try {
            ProcessBuilder pb = new ProcessBuilder("git", "init");
            pb.inheritIO();
            int code = pb.start().waitFor();
            if (code == 0) {
                System.out.println("Repositorio git inicializado correctamente.");
            } else {
                System.err.println("Error al inicializar el repositorio (código " + code + ").");
            }
            return code;
        } catch (Exception e) {
            System.err.println("ERROR: " + e.getMessage());
            return 1;
        }
    }

    private List<String> run(List<String> cmd) {
        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.redirectErrorStream(true);
            Process proc = pb.start();
            List<String> lines;
            try (BufferedReader r = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                lines = r.lines().toList();
            }
            proc.waitFor();
            return lines;
        } catch (Exception e) {
            return List.of("fatal: " + e.getMessage());
        }
    }
}
