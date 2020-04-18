enablePlugins(GhpagesPlugin)

scalaVersion              :=  "2.13.1"
scalacOptions             ++= Seq("-feature", "-language:implicitConversions", "-language:reflectiveCalls")
includeFilter in makeSite :=  "*.yml" | "*.md" | "*.html" | "*.css" | "*.png" | "*.jpg" | "*.gif" | "*.js" | "*.eot" | "*.svg" | "*.ttf" | "*.woff" | "*.woff2" | "*.otf" | "*.ico"
git.remoteRepo            :=  "git@github.com:nrinaudo/nrinaudo.github.com.git"
ghpagesBranch             := "master"
ghpagesNoJekyll           :=  false
