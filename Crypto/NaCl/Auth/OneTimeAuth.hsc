-- |
-- Module      : Crypto.NaCl.Auth.OneTimeAuth
-- Copyright   : (c) Austin Seipp 2011
-- License     : BSD3
-- 
-- Maintainer  : as@hacks.yi.org
-- Stability   : experimental
-- Portability : portable
-- 
-- 
module Crypto.NaCl.Auth.OneTimeAuth 
       ( authenticateOnce     -- :: ByteString -> ByteString -> ByteString
       , verifyOnce           -- :: ByteString -> ByteString -> ByteString -> Bool
       , oneTimeAuthKeyLength -- :: Int
       ) where
import Foreign.Ptr
import Foreign.C.Types
import Data.Word
import Control.Monad (void)

import System.IO.Unsafe (unsafePerformIO)

import Data.ByteString as S
import Data.ByteString.Internal as SI
import Data.ByteString.Unsafe as SU

#include "crypto_onetimeauth.h"

authenticateOnce :: ByteString
                 -- ^ Message
                 -> ByteString 
                 -- ^ Secret key
                 -> ByteString
                 -- ^ Authenticator
authenticateOnce msg k = 
  unsafePerformIO . SI.create auth_BYTES $ \out ->
    SU.unsafeUseAsCStringLen msg $ \(cstr, clen) ->
      SU.unsafeUseAsCString k $ \pk ->
        void $ glue_crypto_onetimeauth out cstr (fromIntegral clen) pk

verifyOnce :: ByteString 
           -- ^ Authenticator
           -> ByteString 
           -- ^ Message
           -> ByteString 
           -- ^ Key
           -> Bool
verifyOnce auth msg k =
  unsafePerformIO $ SU.unsafeUseAsCString auth $ \pauth ->
    SU.unsafeUseAsCStringLen msg $ \(cstr, clen) ->
      SU.unsafeUseAsCString k $ \pk -> do
        b <- glue_crypto_onetimeauth_verify pauth cstr (fromIntegral clen) pk
        return $ if b == 0 then True else False

--
-- FFI
--

oneTimeAuthKeyLength :: Int
oneTimeAuthKeyLength = #{const crypto_onetimeauth_KEYBYTES}

auth_BYTES :: Int
auth_BYTES = #{const crypto_onetimeauth_BYTES}


foreign import ccall unsafe "glue_crypto_onetimeauth"
  glue_crypto_onetimeauth :: Ptr Word8 -> Ptr CChar -> CULLong -> 
                             Ptr CChar -> IO Int

foreign import ccall unsafe "glue_crypto_onetimeauth_verify"
  glue_crypto_onetimeauth_verify :: Ptr CChar -> Ptr CChar -> CULLong -> 
                                    Ptr CChar -> IO Int