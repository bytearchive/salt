{-# LANGUAGE CPP #-}
-- |
-- Module      : Crypto.NaCl.Encrypt.Stream
-- Copyright   : (c) Austin Seipp 2011
-- License     : MIT
-- 
-- Maintainer  : as@hacks.yi.org
-- Stability   : experimental
-- Portability : portable
-- 
-- Fast stream encryption.
-- 
module Crypto.NaCl.Encrypt.Stream
       ( -- * Types
         SecretKey       -- :: *
       , StreamNonce     -- :: * -> *
         -- * Stream generation
       , streamGen       -- :: Nonce -> SecretKey -> ByteString
         -- * Encryption and decryption
       , encrypt         -- :: Nonce -> ByteString -> SecretKey -> ByteString
       , decrypt         -- :: Nonce -> ByteString -> SecretKey -> ByteString
       , keyLength       -- :: Int
       , nonceLength     -- :: Int
       ) where
import Foreign.Ptr
import Foreign.C.Types
import Data.Word
import Control.Monad (void)

import System.IO.Unsafe (unsafePerformIO)

import Data.ByteString as S
import Data.ByteString.Internal as SI
import Data.ByteString.Unsafe as SU

import Crypto.NaCl.Nonce.Internal

type SecretKey = ByteString
data StreamNonce

#include <crypto_stream_xsalsa20.h>

-- | Given a 'Nonce' @n@, size @s@ and 'SecretKey' @sk@, @streamGen n
-- s sk@ generates a cryptographic stream of length @s@.
streamGen :: Nonce StreamNonce
          -- ^ Nonce
          -> Int
          -- ^ Size
          -> SecretKey
          -- ^ Input
          -> ByteString
          -- ^ Resulting crypto stream
streamGen n sz sk
  | nonceLen n /= nonceLengthToInt nonceLength
  = error "Crypto.NaCl.Encrypt.Stream.XSalsa20.streamGen: bad nonce length"
  | S.length sk /= keyLength
  = error "Crypto.NaCl.Encrypt.Stream.XSalsa20.streamGen: bad key length"
  | otherwise
  = unsafePerformIO . SI.create sz $ \out ->
    SU.unsafeUseAsCString (toBS n) $ \pn ->
      SU.unsafeUseAsCString sk $ \psk ->
        void $ c_crypto_stream_xsalsa20 out (fromIntegral sz) pn psk
{-# INLINEABLE streamGen #-}

-- | Given a 'Nonce' @n@, plaintext @p@ and 'SecretKey' @sk@, @encrypt n p sk@ encrypts the message @p@ using 'SecretKey' @sk@ and returns the result.
-- 
-- 'encrypt' guarantees the resulting ciphertext is the plaintext
-- bitwise XOR'd with the result of 'streamGen'. As a result,
-- 'encrypt' can also be used to decrypt messages.
encrypt :: Nonce StreamNonce
        -- ^ Nonce
        -> ByteString
        -- ^ Input plaintext
        -> SecretKey
        -- ^ Secret key
        -> ByteString
        -- ^ Ciphertext
encrypt n msg sk
  | nonceLen n /= nonceLengthToInt nonceLength
  = error "Crypto.NaCl.Encrypt.Stream.XSalsa20.encrypt: bad nonce length"
  | S.length sk /= keyLength
  = error "Crypto.NaCl.Encrypt.Stream.XSalsa20.encrypt: bad key length"
  | otherwise
  = let l = S.length msg
    in unsafePerformIO . SI.create l $ \out ->
      SU.unsafeUseAsCString msg $ \cstr -> 
        SU.unsafeUseAsCString (toBS n) $ \pn ->
          SU.unsafeUseAsCString sk $ \psk ->
            void $ c_crypto_stream_xsalsa20_xor out cstr (fromIntegral l) pn psk
{-# INLINEABLE encrypt #-}

-- | Simple alias for 'encrypt'.
decrypt :: Nonce StreamNonce
        -- ^ Nonce
        -> ByteString
        -- ^ Input ciphertext
        -> SecretKey
        -- ^ Secret key
        -> ByteString
        -- ^ Plaintext
decrypt n c sk = encrypt n c sk
{-# INLINEABLE decrypt #-}


-- 
-- FFI
-- 

-- | Length of a 'SecretKey' needed for encryption/decryption.
keyLength :: Int
keyLength = #{const crypto_stream_xsalsa20_KEYBYTES}

-- | Length of a 'Nonce' needed for encryption/decryption.
nonceLength :: NonceLength StreamNonce
nonceLength = NonceLength #{const crypto_stream_xsalsa20_NONCEBYTES}

foreign import ccall unsafe "glue_crypto_stream_xsalsa20"
  c_crypto_stream_xsalsa20 :: Ptr Word8 -> CULLong -> Ptr CChar -> 
                              Ptr CChar -> IO Int

foreign import ccall unsafe "glue_crypto_stream_xsalsa20_xor"
  c_crypto_stream_xsalsa20_xor :: Ptr Word8 -> Ptr CChar -> 
                                  CULLong -> Ptr CChar -> Ptr CChar -> IO Int