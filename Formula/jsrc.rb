class Jsrc < Formula
  desc "Java source code navigator and analyzer — CLI for codebase exploration"
  homepage "https://github.com/joadpe/jsrc"
  url "https://github.com/joadpe/jsrc/releases/download/v1.0.0/jsrc.jar"
  sha256 "30cd3e293a0e5e0c4e74a58cab7d0cd67bd137f2e948597218a44734ca9bc64b"
  license "MIT"

  depends_on "openjdk"

  resource "tree-sitter" do
    url "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.24.7.tar.gz"
    sha256 "7cbc13c974d6abe978cafc9da12d1e79e07e365c42af75e43ec1b5cdc03ed447"
  end

  resource "tree-sitter-java" do
    url "https://github.com/tree-sitter/tree-sitter-java/archive/refs/tags/v0.23.5.tar.gz"
    sha256 "cb199e0faae4b2c08425f88cbb51c1a9319612e7b96315a174a624db9bf3d9f0"
  end

  def install
    # Build tree-sitter native lib
    resource("tree-sitter").stage do
      system "make", "-j#{ENV.make_jobs}"
      if OS.mac?
        lib.install "libtree-sitter.dylib"
      else
        lib.install "libtree-sitter.so"
      end
      # Save headers for tree-sitter-java build
      (buildpath/"ts-include").install Dir["lib/include/*"]
    end

    # Build tree-sitter-java native lib
    resource("tree-sitter-java").stage do
      if OS.mac?
        system ENV.cc, "-dynamiclib", "-fPIC",
               "-I#{buildpath}/ts-include", "-o", "libtree-sitter-java.dylib", "src/parser.c"
        lib.install "libtree-sitter-java.dylib"
      else
        system ENV.cc, "-shared", "-fPIC",
               "-I#{buildpath}/ts-include", "-o", "libtree-sitter-java.so", "src/parser.c"
        lib.install "libtree-sitter-java.so"
      end
    end

    # Install JAR
    libexec.install "jsrc.jar"

    # Create wrapper script
    (bin/"jsrc").write <<~EOS
      #!/bin/bash
      export JAVA_HOME="#{Formula["openjdk"].opt_prefix}"
      exec "$JAVA_HOME/bin/java" --enable-native-access=ALL-UNNAMED \\
        -Djava.library.path="#{lib}" \\
        -jar "#{libexec}/jsrc.jar" "$@"
    EOS
  end

  test do
    assert_match "jsrc", shell_output("#{bin}/jsrc --help")
  end
end
