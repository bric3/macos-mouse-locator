///usr/bin/env jbang "$0" "$@" ; exit $?
//JAVA 25

import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.GraphicsEnvironment;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Rectangle;
import java.awt.RenderingHints;
import java.awt.Robot;
import java.awt.geom.Path2D;
import java.awt.image.BufferedImage;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import javax.imageio.ImageIO;
import javax.swing.JFrame;
import javax.swing.SwingUtilities;

public class CaptureShowcases {
  private static final int WIDTH = 900;
  private static final int HEIGHT = 520;
  private static final List<Scenario> SCENARIOS = List.of(
      new Scenario("trail", true, false, false),
      new Scenario("idle-pulse", false, true, false),
      new Scenario("both", true, true, false),
      new Scenario("rainbow-trail", true, false, true));

  public static void main(String[] args) throws Exception {
    Path root = Path.of(System.getProperty("user.dir"));
    Path app = root.resolve(".build/MouseLocator.app/Contents/MacOS/MouseLocator");
    if (!Files.isExecutable(app)) {
      throw new IllegalStateException("Run `make app` before capturing screenshots");
    }

    Path output = root.resolve("github/docs/images");
    Files.createDirectories(output);
    Path configHome = Files.createTempDirectory("mouse-locator-showcase-");
    Path installedApp = Path.of(
        System.getProperty("user.home"), "Applications", "MouseLocator.app");
    Path installedBinary = installedApp.resolve("Contents/MacOS/MouseLocator");
    boolean restartInstalledApp = isRunning(installedBinary);
    stopMouseLocatorProcesses();

    Rectangle screen = GraphicsEnvironment.getLocalGraphicsEnvironment().getMaximumWindowBounds();
    Rectangle panel = new Rectangle(
        screen.x + (screen.width - WIDTH) / 2,
        screen.y + (screen.height - HEIGHT) / 2,
        WIDTH,
        HEIGHT);
    JFrame frame = createPanel(panel);
    Robot robot = new Robot();

    try {
      for (boolean dark : List.of(false, true)) {
        setBackground(frame, dark ? new Color(0x18, 0x18, 0x18) : new Color(0xfa, 0xfa, 0xfa));
        for (Scenario scenario : SCENARIOS) {
          capture(app, configHome, output, panel, robot, scenario, dark);
        }
      }
      verifyScreenshots(output);
    } finally {
      SwingUtilities.invokeAndWait(frame::dispose);
      Files.deleteIfExists(configHome.resolve("mouse-locator/settings.json"));
      Files.deleteIfExists(configHome.resolve("mouse-locator"));
      Files.deleteIfExists(configHome);
      if (restartInstalledApp) {
        new ProcessBuilder("/usr/bin/open", "-n", installedApp.toString()).start().waitFor();
      }
    }

    System.out.println("Wrote light and dark showcase screenshots to " + output);
  }

  private static void capture(
      Path app,
      Path configHome,
      Path output,
      Rectangle panel,
      Robot robot,
      Scenario scenario,
      boolean dark) throws Exception {
    stopMouseLocatorProcesses();
    Point start = scenario.tail
        ? new Point(panel.x + 120, panel.y + HEIGHT * 3 / 4)
        : new Point(panel.x + WIDTH / 2 - 2, panel.y + HEIGHT / 2);
    robot.mouseMove(start.x, start.y);

    Path settings = configHome.resolve("mouse-locator/settings.json");
    Files.createDirectories(settings.getParent());
    Files.writeString(settings, settings(scenario, dark));

    Process overlay = new ProcessBuilder(app.toString(), "--config-home=" + configHome)
        .redirectError(ProcessBuilder.Redirect.INHERIT)
        .redirectOutput(ProcessBuilder.Redirect.INHERIT)
        .start();
    try {
      Thread.sleep(scenario.pulse ? 1_300 : 500);
      if (scenario.tail) {
        moveAlongTrail(robot, panel);
      } else {
        robot.mouseMove(start.x + 4, start.y);
        Thread.sleep(1_000);
      }

      Thread.sleep(40);
      Point cursor = MouseInfo.getPointerInfo().getLocation();
      Path image = output.resolve(
          scenario.name + (dark ? "-dark.png" : "-light.png"));
      BufferedImage screenshot = robot.createScreenCapture(panel);
      drawCursor(screenshot, cursor.x - panel.x, cursor.y - panel.y);
      ImageIO.write(screenshot, "png", image.toFile());
    } finally {
      stop(overlay);
    }
  }

  private static void moveAlongTrail(Robot robot, Rectangle panel) throws InterruptedException {
    for (int step = 0; step <= 70; step++) {
      double t = step / 70.0;
      int x = panel.x + 120 + (int) ((WIDTH - 240) * t);
      int y = panel.y + HEIGHT * 3 / 4
          - (int) (HEIGHT * 0.42 * Math.sin(Math.PI * t))
          + (int) (35 * Math.sin(2 * Math.PI * t));
      robot.mouseMove(x, y);
      Thread.sleep(5);
    }
  }

  private static void drawCursor(BufferedImage image, int x, int y) {
    Graphics2D graphics = image.createGraphics();
    graphics.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
    graphics.translate(x, y);
    Path2D cursor = new Path2D.Double();
    cursor.moveTo(0, 0);
    cursor.lineTo(1, 30);
    cursor.lineTo(8, 23);
    cursor.lineTo(14, 35);
    cursor.lineTo(20, 32);
    cursor.lineTo(14, 21);
    cursor.lineTo(25, 20);
    cursor.closePath();
    graphics.setColor(Color.WHITE);
    graphics.fill(cursor);
    graphics.setColor(Color.BLACK);
    graphics.setStroke(new BasicStroke(2.5f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
    graphics.draw(cursor);
    graphics.dispose();
  }

  private static String settings(Scenario scenario, boolean dark) {
    String color = dark ? "#69AFFF" : "#006BD6";
    return """
        {
          "sonarColor": "%s",
          "sonarDelay": 1,
          "sonarEnabled": %s,
          "sonarRainbow": false,
          "sonarSize": 240,
          "sonarThickness": 3,
          "tailColor": "%s",
          "tailDotsEnabled": false,
          "tailEnabled": %s,
          "tailGap": 16,
          "tailRainbow": %s,
          "tailSmoothing": "bezier",
          "tailThickness": 3
        }
        """.formatted(color, scenario.pulse, color, scenario.tail, scenario.rainbow);
  }

  private static JFrame createPanel(Rectangle bounds) throws Exception {
    AtomicReference<JFrame> result = new AtomicReference<>();
    SwingUtilities.invokeAndWait(() -> {
      JFrame frame = new JFrame("Mouse Locator Showcase");
      frame.setUndecorated(true);
      frame.setAlwaysOnTop(true);
      frame.setBounds(bounds);
      frame.setVisible(true);
      result.set(frame);
    });
    return result.get();
  }

  private static void setBackground(JFrame frame, Color color) throws Exception {
    SwingUtilities.invokeAndWait(() -> {
      frame.getContentPane().setBackground(color);
      frame.repaint();
      frame.toFront();
    });
    Thread.sleep(150);
  }

  private static boolean isRunning(Path executable) throws Exception {
    return new ProcessBuilder(
        "/usr/bin/pgrep", "-f", "^" + executable + "( |$)")
        .start()
        .waitFor() == 0;
  }

  private static void stopMouseLocatorProcesses() throws Exception {
    new ProcessBuilder(
        "/usr/bin/pkill", "-f", "MouseLocator\\.app/Contents/MacOS/MouseLocator( |$)")
        .start()
        .waitFor();
    Thread.sleep(150);
  }

  private static void stop(Process process) throws Exception {
    process.destroy();
    if (!process.waitFor(Duration.ofSeconds(2))) {
      process.destroyForcibly();
      process.waitFor();
    }
  }

  private static void verifyScreenshots(Path output) throws Exception {
    for (Scenario scenario : SCENARIOS) {
      for (String appearance : List.of("light", "dark")) {
        Path path = output.resolve(scenario.name + "-" + appearance + ".png");
        BufferedImage image = ImageIO.read(path.toFile());
        if (image == null || image.getWidth() < WIDTH || image.getHeight() < HEIGHT) {
          throw new IllegalStateException("Invalid screenshot: " + path);
        }
      }
    }
  }

  private record Scenario(String name, boolean tail, boolean pulse, boolean rainbow) {}
}
