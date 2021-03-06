{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
-- | Parsing based on RFC1459
--
-- Deviations from the spec:
-- * We parse host names according to RFC 1123 rather than the older RFC952.
module Network.IRC.ByteString.RFC1459 (
    rfc1459Conf
    -- |parsers
    , channel, nick, user, host, param
    -- |predicates
    , Network.IRC.ByteString.RFC1459.isIRCSpace, isNonWhite, isChanPrefix, isChanChar, isTargetMaskPrefix, isFirstNickChar, isNickChar, isSpecial, isUserChar
) where

import Data.Attoparsec.Char8 as Char8
import Data.Char

import Network.IRC.ByteString.Utils
import Network.IRC.ByteString.HostParser
import Network.IRC.ByteString.Config
import Prelude hiding (takeWhile)


-- |Only the octet 0x20 is defined as a valid space.
-- > <SPACE>    ::= ' ' { ' ' } 
isIRCSpace = (== ' ')

-- | > <nonwhite>   ::= <any 8bit code except SPACE (0x20), NUL (0x0), CR (0xd), and LF (0xa)>
isNonWhite c = c /= ' ' && c /= '\r' && c /= '\n' && c /= '\0'

-- |Tests if a character is a valid channel prefix.
-- '#' and '&' are the only valid channel prefix characters
isChanPrefix c = c == '#' || c  == '&'

-- |Tests is a character is a valid target mask prefix
-- '#' and '$' are the only valid characters
isTargetMaskPrefix c = c == '#' || c == '$'

-- |Tests if a character is valid in a channel string.
-- > <chstring>   ::= <any 8bit code except SPACE, BELL, NUL, CR, LF and comma (',')>
isChanChar c = isNonWhite c && c /= '\x007' && c /= ','

-- |Tests if a character is valid as the first character in a nick string.
isFirstNickChar = isAlphaNum

-- |Tests if a character is valid as a non-first character in a nick string.
isNickChar c = isAlphaNum c || isSpecial c

-- |Tests if a character is special.
-- > <special>    ::= '-' | '[' | ']' | '\' | '`' | '^' | '{' | '}'
isSpecial c = c == '-' || c == '[' || c == ']' || c == '\\' || c == '`'
              || c == '^' || c == '{' || c == '}' || c == '_'

-- |Tests if a character is valid in a user string             
isUserChar c = isNonWhite c && c /= '@'
       

{- | RFC1459 channel name.

   @
      <channel>    ::= ('#' | '&') <chstring>
      <chstring>   ::= <any 8bit code except SPACE, BELL, NUL, CR, LF and comma (',')>
   @
-}
channel = prefix <:> name
    where prefix = satisfy isChanPrefix <?> "channel prefix"
          name = Char8.takeWhile isChanChar   <?> "channel name"

          


{- |RFC1459 nick name

   @
       <nick>       ::= <letter> { <letter> | <number> | <special> }
       <letter>     ::= 'a' ... 'z' | 'A' ... 'Z'
       <number>     ::= '0' ... '9'
       <special>    ::= '-' | '[' | ']' | '\' | '`' | '^' | '{' | '}'
   @
-}

nick = satisfy isFirstNickChar <:> Char8.takeWhile isNickChar 
       <?> "nick"

-- |RFC1459 user name (see 'isNonWhite')
--
-- > <user>       ::= <nonwhite> { <nonwhite> }
user = takeWhile1 isUserChar 
       <?> "username" 

-- |Parses a single command paramter according to RFC1459
--
-- @
--     <middle>   ::= <Any *non-empty* sequence of octets not including SPACE or NUL or CR or LF, the first of which may not be ':'>
-- @
param = satisfy (\c -> isNonWhite c && c /= ':')
                <:> Char8.takeWhile isNonWhite      

-- |Parse options for adhering to RFC1459
rfc1459Conf = IRCParserConfig
    { nickParser = nick
    , userParser = user
    , hostParser = host
    , paramParser = param
    , Network.IRC.ByteString.Config.isIRCSpace = Network.IRC.ByteString.RFC1459.isIRCSpace
    }