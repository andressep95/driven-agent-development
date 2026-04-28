package com.cloudcentinel;

import com.cloudcentinel.commands.InitRepoCommand;
import com.cloudcentinel.commands.ScanGitConfigCommand;
import com.cloudcentinel.commands.SetupAgentCommand;
import picocli.CommandLine;
import picocli.CommandLine.Command;

@Command(
    name = "agent",
    description = "Driven Agent Development CLI",
    mixinStandardHelpOptions = true,
    subcommands = {
        InitRepoCommand.class,
        SetupAgentCommand.class,
        ScanGitConfigCommand.class
    }
)
public class App {

    public static void main(String[] args) {
        int exit = new CommandLine(new App()).execute(args);
        System.exit(exit);
    }
}
