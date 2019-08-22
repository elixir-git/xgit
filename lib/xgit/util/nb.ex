# Copyright (C) 2008, 2015 Shawn O. Pearce <spearce@spearce.org>
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit/src/org/eclipse/jgit/util/NB.java
#
# Copyright (C) 2019, Eric Scouten <eric+xgit@scouten.com>
#
# This program and the accompanying materials are made available
# under the terms of the Eclipse Distribution License v1.0 which
# accompanies this distribution, is reproduced below, and is
# available at http://www.eclipse.org/org/documents/edl-v10.php
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# - Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the following
#   disclaimer in the documentation and/or other materials provided
#   with the distribution.
#
# - Neither the name of the Eclipse Foundation, Inc. nor the
#   names of its contributors may be used to endorse or promote
#   products derived from this software without specific prior
#   written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

defmodule Xgit.Util.NB do
  @moduledoc ~S"""
  Conversion utilities for network byte order handling.
  """

  use Bitwise

  @doc ~S"""
  Parses a sequence of 4 bytes (network byte order) as a signed integer.

  Reads the first four bytes from `intbuf` and returns `{value, buf}`
  where value is the integer value from the first four bytes at `intbuf`
  and `buf` is the remainder of the byte array after those bytes.
  """
  @spec decode_int32(intbuf :: [byte]) :: {integer, [byte]}
  def decode_int32(intbuf)

  def decode_int32([b1, b2, b3, b4 | tail]) when b1 >= 128,
    do: {b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4 - 0x100000000, tail}

  def decode_int32([b1, b2, b3, b4 | tail]),
    do: {b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4, tail}

  @doc ~S"""
  Parses a sequence of 2 bytes (network byte order) as an unsigned integer.

  Reads the first four bytes from `intbuf` and returns `{value, buf}`
  where value is the unsigned integer value from the first two bytes at `intbuf`
  and `buf` is the remainder of the byte array after those bytes.
  """
  @spec decode_uint16(intbuf :: [byte]) :: {integer, [byte]}
  def decode_uint16(intbuf)
  def decode_uint16([b1, b2 | tail]), do: {b1 * 0x100 + b2, tail}

  @doc ~S"""
  Parses a sequence of 4 bytes (network byte order) as an unsigned integer.

  Reads the first four bytes from `intbuf` and returns `{value, buf}`
  where value is the unsigned integer value from the first four bytes at `intbuf`
  and `buf` is the remainder of the byte array after those bytes.
  """
  @spec decode_uint32(intbuf :: [byte]) :: {integer, [byte]}
  def decode_uint32(intbuf)

  def decode_uint32([b1, b2, b3, b4 | tail]),
    do: {b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4, tail}

  @doc ~S"""
  Convert a 16-bit integer to a sequence of two bytes in network byte order.
  """
  @spec encode_int16(v :: integer) :: [byte]
  def encode_int16(v) when is_integer(v) and v >= -32_768 and v <= 65_535,
    do: [v >>> 8 &&& 0xFF, v &&& 0xFF]

  @doc ~S"""
  Convert a 32-bit integer to a sequence of four bytes in network byte order.
  """
  @spec encode_int32(v :: integer) :: [byte]
  def encode_int32(v) when is_integer(v) and v >= -2_147_483_647 and v <= 4_294_967_295,
    do: [v >>> 24 &&& 0xFF, v >>> 16 &&& 0xFF, v >>> 8 &&& 0xFF, v &&& 0xFF]

  @doc ~S"""
  Convert a 16-bit unsigned integer to a sequence of two bytes in network byte order.
  """
  @spec encode_uint16(v :: non_neg_integer) :: [byte]
  def encode_uint16(v) when is_integer(v) and v >= 0 and v <= 65_535,
    do: [v >>> 8 &&& 0xFF, v &&& 0xFF]

  @doc ~S"""
  Convert a 32-bit unsigned integer to a sequence of four bytes in network byte order.
  """
  @spec encode_uint32(v :: non_neg_integer) :: [byte]
  def encode_uint32(v) when is_integer(v) and v >= 0 and v <= 4_294_967_295,
    do: [v >>> 24 &&& 0xFF, v >>> 16 &&& 0xFF, v >>> 8 &&& 0xFF, v &&& 0xFF]
end
