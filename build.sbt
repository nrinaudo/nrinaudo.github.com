import com.typesafe.sbt.SbtSite.SiteKeys._
import com.typesafe.sbt.SbtGhPages.GhPagesKeys._

scalaVersion := "2.11.7"

tutSettings

site.settings

site.addMappingsToSiteDir(tut, "_posts")

includeFilter in makeSite := "*.yml" | "*.md" | "*.html" | "*.css" | "*.png" | "*.jpg" | "*.gif" | "*.js" | "*.eot" | "*.svg" | "*.ttf" | "*.woff" | "*.woff2" | "*.otf"

ghpages.settings

git.remoteRepo := "git@github.com:nrinaudo/tabulate.git"

ghpagesNoJekyll := false

scalacOptions ++= Seq("-deprecation",
  "-target:jvm-1.7",
  "-encoding", "UTF-8",
  "-feature",
  "-language:existentials",
  "-language:higherKinds",
  "-language:implicitConversions",
  "-unchecked",
  "-Xfatal-warnings",
  "-Xlint",
  "-Yno-adapted-args",
  "-Ywarn-dead-code",
  "-Ywarn-numeric-widen",
  "-Ywarn-value-discard",
  "-Xfuture")

libraryDependencies ++= Seq(
  "org.typelevel"        %% "export-hook"   % "1.1.0",
  "org.scala-lang"        % "scala-reflect" % scalaVersion.value  % "provided",
  "com.github.mpilquist" %% "simulacrum"    % "0.5.0"             % "provided",
  "com.chuusai"          %% "shapeless"     % "2.2.5",
  compilerPlugin("org.scalamacros" % "paradise" % "2.1.0" cross CrossVersion.full)
)
