class Jsrc < Formula
  desc "Java source code navigator and analyzer — CLI for codebase exploration"
  homepage "https://github.com/joadpe/jsrc"
  url "https://github.com/joadpe/jsrc/releases/download/v1.0.11/jsrc.jar"
  sha256 "146fe00cc4c2255e8425dc014260a10300a2ff54246a22d87564e724defc3f3f"
  license "MIT"

  depends_on "openjdk"

  resource "tree-sitter" do
    url "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.25.6.tar.gz"
    sha256 "ac6ed919c6d849e8553e246d5cd3fa22661f6c7b6497299264af433f3629957c"
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
        # Fix install name so dependents can find it
        system "install_name_tool", "-id", "#{lib}/libtree-sitter.dylib",
               "#{lib}/libtree-sitter.dylib"
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
               "-I#{buildpath}/ts-include",
               "-L#{lib}", "-ltree-sitter",
               "-install_name", "#{lib}/libtree-sitter-java.dylib",
               "-o", "libtree-sitter-java.dylib", "src/parser.c"
        lib.install "libtree-sitter-java.dylib"
        # Fix references to libtree-sitter to use absolute Cellar path
        # The make build may embed various versioned names
        ["libtree-sitter.0.25.dylib", "libtree-sitter.0.24.dylib",
         "libtree-sitter.dylib"].each do |old_name|
          system "install_name_tool",
                 "-change", "/usr/local/lib/#{old_name}",
                 "#{lib}/libtree-sitter.dylib",
                 "#{lib}/libtree-sitter-java.dylib"
        end
      else
        system ENV.cc, "-shared", "-fPIC",
               "-I#{buildpath}/ts-include",
               "-L#{lib}", "-ltree-sitter",
               "-o", "libtree-sitter-java.so", "src/parser.c"
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
        -Xmx2g \\
        -Djava.library.path="#{lib}" \\
        -jar "#{libexec}/jsrc.jar" "$@"
    EOS
  end

  test do
    assert_match "jsrc", shell_output("#{bin}/jsrc --help")
  end
end
