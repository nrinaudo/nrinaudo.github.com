enablePlugins(DocumentationPlugin)

git.remoteRepo := "git@github.com:nrinaudo/nrinaudo.github.com.git"

libraryDependencies ++= Seq(
  "com.chuusai"          %% "shapeless"  % Versions.shapeless,
  "com.github.mpilquist" %% "simulacrum" % Versions.simulacrum
)

addCompilerPlugin("org.scalamacros" % "paradise" % "2.1.0" cross CrossVersion.full)

tutTargetDirectory := (sourceDirectory in Preprocess).value / "_posts"

ghpagesBranch := "master"
