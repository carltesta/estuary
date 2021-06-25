{-# LANGUAGE OverloadedStrings #-}

module Estuary.Languages.Hydra.Parser where

import Data.Text (Text)
import qualified Data.Text as T
import Text.Parsec
import Text.Parsec.Text

import qualified Text.ParserCombinators.Parsec.Token as P
import Control.Monad.Identity (Identity)

import Estuary.Languages.Hydra.Types
import Estuary.Languages.Hydra.Test

----

parseHydra :: Text -> Either ParseError [Statement]
parseHydra s = parse hydra "hydra" s

hydra :: Parser [Statement]
hydra = do
  whiteSpace
  xs <- semiSep statement
  eof
  return xs

statement :: Parser Statement
statement = try $ choice [
  try outStatement,
  try renderStatement,
  try $ inputStatementParameters "initCam" InitCam,
  try $ inputStatementParameters "initScreen" InitScreen,
  try $ inputStatementString "initVideo" InitVideo,
  try $ inputStatementString "initImage" InitImage,
  try speedStatement,
  try setResolutionStatement
  ]

outStatement :: Parser Statement
outStatement = do
  s <- source
  reservedOp "."
  reserved "out"
  o <- output
  return $ Out s o

output :: Parser Output
output = try $ parens $ choice [
  outputNoDefault,
  whiteSpace >> return O0
  ]

--render() -- render(o1)
renderStatement :: Parser Statement
renderStatement = do
  reserved "render"
  p <- parens $ outputForRender
  case p of
    All -> return $ Render Nothing
    x -> return $ Render (Just x)

outputForRender :: Parser Output
outputForRender = try $ choice [
  outputNoDefault,
  whiteSpace >> return All
  ]

-- s1.initCam() or s1.initCam(1), s0.initScreen()
inputStatementParameters :: String -> (Input -> [Parameters] -> Statement) -> Parser Statement
inputStatementParameters x z = do
  i <- input
  reservedOp "."
  reserved x
  let param = (Parameters . return) <$> double
  p <- parens $ commaSep param
  return $ z i p

-- s0.initVideo(url) s0.initImage(url)
inputStatementString :: String -> (Input -> Text -> Statement) -> Parser Statement
inputStatementString x z = do
  i <- input
  reservedOp "."
  reserved x
  s <- parens stringLiteral
  return $ z i (T.pack s)

input :: Parser Input
input = try $ choice [
  reserved "s0" >> return S0,
  reserved "s1" >> return S1,
  reserved "s2" >> return S2,
  reserved "s3" >> return S3
  ]

speedStatement :: Parser Statement -- speed=0.5 or speed = 0.5
speedStatement = do
  reserved "speed"
  reservedOp "="
  p <- (Parameters . return) <$> double
  return $ Speed p

setResolutionStatement :: Parser Statement -- setResolution(w,h)
setResolutionStatement = do
  reserved "setResolution"
  let param = (Parameters . return) <$> double
  p <- parens $ commaSep param
  return $ SetResolution p


source :: Parser Source
source = do
  x <- choice [ -- a source is a single "atomic" Source...
    functionWithParameters "osc" Osc,
    functionWithParameters "solid" Solid,
    functionWithParameters "gradient" Gradient,
    functionWithParameters "noise" Noise,
    functionWithParameters "shape" Shape,
    functionWithParameters "voronoi" Voronoi,
    srcFunction
    ]
  fs <- many $ choice [ -- ...to which zero or more transformations [Source -> Source] are applied.
    methodWithParameters "brightness" Brightness,
    methodWithParameters "contrast" Contrast,
    methodWithParameters "colorama" Colorama,
    methodWithParameters "color" Color,
    methodWithParameters "invert" Invert,
    methodWithParameters "luma" Luma,
    methodWithParameters "hue" Hue,
    methodWithParameters "posterize" Posterize,
    methodWithParameters "saturate" Saturate,
    methodWithParameters "shift" Shift,
    methodWithParameters "thresh" Thresh,
    methodWithParameters "kaleid" Kaleid,
    methodWithParameters "pixelate" Pixelate,
    methodWithParameters "repeat" Repeat,
    methodWithParameters "repeatX" RepeatX,
    methodWithParameters "repeatY" RepeatY,
    methodWithParameters "rotate" Rotate,
    methodWithParameters "scale" Scale,
    methodWithParameters "scroll" Scroll,
    methodWithParameters "scrollX" ScrollX,
    methodWithParameters "scrollY" ScrollY,
    methodWithSourceAndParameters "modulate" Modulate,
    methodWithSourceAndParameters "modulateHue" ModulateHue,
    methodWithSourceAndParameters "modulateKaleid" ModulateKaleid,
    methodWithSourceAndParameters "modulatePixelate" ModulatePixelate,
    methodWithSourceAndParameters "modulateRepeat" ModulateRepeat,
    methodWithSourceAndParameters "modulateRepeatX" ModulateRepeatX,
    methodWithSourceAndParameters "modulateRepeatY" ModulateRepeatY,
    methodWithSourceAndParameters "modulateRotate" ModulateRotate,
    methodWithSourceAndParameters "modulateScale" ModulateScale,
    methodWithSourceAndParameters "modulateScrollX" ModulateScrollX,
    methodWithSourceAndParameters "modulateScrollY" ModulateScrollY,
    methodWithSourceAndParameters "add" Add,
    methodWithSourceAndParameters "mult" Mult,
    methodWithSourceAndParameters "blend" Blend,
    methodWithSourceAndParameters "mask" Mask,
    methodWithSourceAndParameters "diff" Diff,
    methodWithSourceAndParameters "layer" Layer
    ]
  return $ (foldl (.) id $ reverse fs) x -- compose the transformations into a single transformation and apply to source


-- src(s0) or src(o2,1)
srcFunction :: Parser Source
srcFunction = do
  reserved "src"
  (s,ps) <- parens $ do
    s <- srcFunctionArgument
    let param = (Parameters . return) <$> double
    ps <- (comma >> commaSep param) <|> return []
    return (s,ps)
  return $ Src s ps


srcFunctionArgument :: Parser Source
srcFunctionArgument = try $ choice [
  try inputAsSource, --s0,s1,s2,s3
  try outputAsSource --o0,o1,o2,o3
  ]

inputAsSource :: Parser Source
inputAsSource = do
  s <- input
  return $ InputAsSource s


sourceAsArgument :: Parser Source
sourceAsArgument = try $ choice [
  try outputAsSource, --o0,o1,o2,o3
  try source -- osc()
  ]

outputAsSource :: Parser Source
outputAsSource = do
  s <- outputNoDefault
  return $ OutputAsSource s

outputNoDefault :: Parser Output
outputNoDefault = try $ choice [
  reserved "o0" >> return O0,
  reserved "o1" >> return O1,
  reserved "o2" >> return O2,
  reserved "o3" >> return O3
  ]

functionWithParameters :: String -> ([Parameters] -> Source) -> Parser Source
functionWithParameters funcName constructor = try $ do
  reserved funcName
  ps <- parens $ commaSep parameters
  return $ constructor ps

methodWithParameters :: String -> ([Parameters] -> Source -> Source) -> Parser (Source -> Source)
methodWithParameters methodName constructor = try $ do
  reservedOp "."
  reserved methodName
  ps <- parens $ commaSep parameters
  return $ constructor ps

methodWithSource :: String -> (Source -> Source -> Source) -> Parser (Source -> Source) -- osc().diff(osc()).out()
methodWithSource methodName constructor = try $ do
  reservedOp "."
  reservedOp methodName
  s <- parens $ sourceAsArgument
  return $ constructor s

methodWithSourceAndParameters :: String -> (Source -> [Parameters] -> Source -> Source) -> Parser (Source -> Source) -- osc().mask(osc(),0.5,0.8).out()  -- mask(o1)
methodWithSourceAndParameters methodName constructor = try $ do
  reservedOp "."
  reservedOp methodName
  (s,ps) <- parens $ do
    s <- sourceAsArgument
    ps <- (comma >> commaSep1 parameters) <|> return []
    return (s,ps)
  return $ constructor s ps

parameters :: Parser Parameters
parameters =
  transformationParameters <|>
  (Parameters . return) <$> double

transformationParameters :: Parser Parameters
transformationParameters = do
  x <- Parameters <$> try (brackets (commaSep double))
  fs <- many $ choice [
    methodForLists "fast" Fast,
    methodForLists "smooth" Smooth
    ]
  return $ (foldl (.) id $ reverse fs) x

methodForLists :: String -> ([Double] -> Parameters -> Parameters) -> Parser (Parameters -> Parameters)
methodForLists methodName constructor = try $ do
  reservedOp "."
  reservedOp methodName
  p <- parens $ commaSep double
  return $ constructor p

double :: Parser Double
double = choice [
  symbol "-" >> double >>= return . (* (-1)),
  symbol "-" >> doubleWithoutPrecedingZero >>= return . (*(-1)),
  try doubleWithoutPrecedingZero,
  try float,
  try $ fromIntegral <$> integer
  ]

doubleWithoutPrecedingZero :: Parser Double
doubleWithoutPrecedingZero = do
  symbol "."
  p <- fromIntegral <$> integer
  return $ read ("0." ++ show p)


---------

tokenParser :: P.GenTokenParser Text () Identity
tokenParser = P.makeTokenParser $ P.LanguageDef {
  P.commentStart = "/*",
  P.commentEnd = "*/",
  P.commentLine = "//",
  P.nestedComments = False,
  P.identStart = letter <|> char '_',
  P.identLetter = alphaNum <|> char '_',
  P.opStart = oneOf ".",
  P.opLetter = oneOf ".",
  P.reservedNames = [
    "out","render", "fast", "smooth", "speed", "setResolution",
    "osc","solid","gradient","noise","shape","voronoi",
    "brightness", "contrast", "colorama", "color", "invert", "luma", "hue", "posterize", "saturate", "shift", "thresh", "kaleid", "pixelate", "repeat", "repeatX", "repeatY", "rotate", "scale", "scroll", "scrollX", "scrollY",
    "modulate", "modulateHue", "modulateKaleid", "modulatePixelate", "modulateRepeat", "modulateRepeatX", "modulateRepeatY", "modulateRotate", "modulateScale", "modulateScrollX", "modulateScrollY",
    "add", "mult", "blend", "diff", "layer", "mask",
    "o0","o1","o2","o3", "s0", "s1", "s2", "s3", "initScreen", "initCam", "initVideo", "initImage"
    ],
  P.reservedOpNames = [".", "="],
  P.caseSensitive = False
  }


identifier = P.identifier tokenParser
reserved = P.reserved tokenParser
operator = P.operator tokenParser
reservedOp = P.reservedOp tokenParser
charLiteral = P.charLiteral tokenParser
stringLiteral = P.stringLiteral tokenParser
natural = P.natural tokenParser
integer = P.integer tokenParser
float = P.float tokenParser
naturalOrFloat = P.naturalOrFloat tokenParser
decimal = P.decimal tokenParser
hexadecimal = P.hexadecimal tokenParser
octal = P.octal tokenParser
symbol = P.symbol tokenParser
lexeme = P.lexeme tokenParser
whiteSpace = P.whiteSpace tokenParser
parens = P.parens tokenParser
braces = P.braces tokenParser
angles = P.angles tokenParser
brackets = P.brackets tokenParser
semi = P.semi tokenParser
comma = P.comma tokenParser
colon = P.colon tokenParser
dot = P.dot tokenParser
semiSep = P.semiSep tokenParser
semiSep1 = P.semiSep1 tokenParser
commaSep = P.commaSep tokenParser
commaSep1 = P.commaSep1 tokenParser
