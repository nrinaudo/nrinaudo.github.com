{-# LANGUAGE OverloadedStrings #-}
import Data.Monoid                 ((<>), mconcat)
import Data.List                   (intersperse)
import Hakyll
import Text.Blaze.Html             (toHtml, toValue, (!))
import Text.Blaze.Html5            (Html, a)
import Text.Blaze.Html5.Attributes (href, class_)

hakyllConf :: Configuration
hakyllConf = defaultConfiguration {
  providerDirectory    = "./src/hakyll/",
  destinationDirectory = "./tmp/site",
  storeDirectory       = "./tmp/cache",
  tmpDirectory         = "./tmp/tmp"
  }


main :: IO ()
main = hakyllWith hakyllConf $ do
  tags <- buildTags "posts/*" (fromCapture "tags/*.html")

  let postContext = dateField   "date"   "%F"      <>
                    teaserField "teaser" "content" <>
                    tagsField'  "tags"   tags      <>
                    defaultContext


  -- Images ------------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------
  -- Compile dot files as SVG.
  match "images/**.dot" $ do
    route   $ setExtension "svg"
    compile $ getResourceString >>=
      withItemBody (unixFilter "dot" ["-Tsvg"])

  -- Other images are simply copied.
  match "images/**" $ do
    route   idRoute
    compile copyFileCompiler



  -- CSS & fonts -------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------
  match "fonts/*" $ do
    route   idRoute
    compile copyFileCompiler

  match "css/*" $ do
    route   idRoute
    compile compressCssCompiler



  -- All posts ---------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------
  match "posts/*" $ do
    route $ setExtension "html"
    compile $ pandocCompiler
      >>= saveSnapshot "content"
      >>= loadAndApplyTemplate "templates/post.html" postContext
      >>= loadAndApplyTemplate "templates/layout.html" defaultContext
      >>= relativizeUrls



  -- Archives page -----------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------
  create ["archive.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let archiveCtx =
            listField "posts" postContext (return posts) <>
            constField "title" "Archives"                <>
            defaultContext

      makeItem ""
        >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
        >>= loadAndApplyTemplate "templates/layout.html" archiveCtx
        >>= relativizeUrls



  -- Homepage ----------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------
  match "index.html" $ do
    route idRoute
    compile $ do
      posts <- fmap (take 10) $ recentFirst =<< loadAllSnapshots "posts/*" "content"
      let indexCtx =
            listField "posts" postContext (return posts) <>
            defaultContext

      getResourceBody
        >>= applyAsTemplate indexCtx
        >>= loadAndApplyTemplate "templates/layout.html" indexCtx
        >>= relativizeUrls



  -- Tags --------------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------
  tagsRules tags $ \tag pattern -> do
    route idRoute
    compile $ do
      posts    <- recentFirst =<< loadAll pattern
      template <- loadBody "templates/post-header.html"
      list     <- applyTemplateList template postContext posts

      let tagContext = constField "title" ("Posts tagged " ++ tag) <>
                       constField "posts" list                     <>
                       defaultContext

      makeItem ""
        >>= loadAndApplyTemplate "templates/tag.html" tagContext
        >>= loadAndApplyTemplate "templates/layout.html" defaultContext
        >>= relativizeUrls



  -- Templates ---------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------
  match "templates/*" $ compile templateCompiler



-- Helpers -------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
-- Custom version of tagsField that:
-- - marks each tag's link with a "tag" class
-- - separates tags by a | rather than a ,
tagsField' :: String -> Tags -> Context a
tagsField' = tagsFieldWith getTags renderTag (mconcat . intersperse " | ")

-- Renders a tag as a link with a "tag" class.
renderTag :: String -> Maybe FilePath -> Maybe Html
renderTag _   Nothing         = Nothing
renderTag tag (Just filePath) = Just $ a ! href (toValue $ toUrl filePath) ! class_ "tag" $ toHtml tag
