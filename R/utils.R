# // Copyright (C) 2015 - 2016  Dmitriy Selivanov
# // This file is part of text2vec
# //
#   // text2vec is free software: you can redistribute it and/or modify it
# // under the terms of the GNU General Public License as published by
# // the Free Software Foundation, either version 2 of the License, or
# // (at your option) any later version.
# //
#   // text2vec is distributed in the hope that it will be useful, but
# // WITHOUT ANY WARRANTY; without even the implied warranty of
# // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# // GNU General Public License for more details.
# //
#   // You should have received a copy of the GNU General Public License
# // along with text2vec.  If not, see <http://www.gnu.org/licenses/>.

# @name split_vector
# @title Generating indexes for splitting vector into chunks
# @description Generating indexes for splitting vector into chunks for parallel processing.
# @details Parameters granularity and splits controls the numer of chunks in returned list.
# Number of chunks in resulted list in general is equal granularity * splits
# @param vec \link{list} or \link{vector} to split
# @param granularity \link{integer} -  granularity is useful for management of granularity
# of splits. If you expect that computational time on each chunk of your data will
# be distributed nerarly uniformly, granularity = 1 is good choice because of little overheads
# in syncronizing parallel processes.
# @param splits \link{integer} - controls number of parallel jobs you have planned.
# Usually should be equal to number of cores in the machine.
# @return \link{list} each element is a \link{integer} \link{vector} pair.
# First element in pair is lower index, second element is upper index.
split_vector = function(vec, splits, granularity = 1) {
  if ( !is.vector(vec)) stop("vec must be vector or list")
  if (length(vec) < splits * granularity) {
    warning("Length of input is too small for splitting for a given number
            of splits and level of parallerism. Assuming no splits.")
    return(list(c(1, length(vec))))
  }
  knots = ceiling(seq.int(from = 1, to = length(vec) + 1,
                          length.out = splits * granularity + 1))
  mapply(FUN = function(lower, upper) list(c(lower, upper)), knots[-length(knots)], knots[-1] - 1)
}

#' @name as.lda_c
#' @title Converts document-term matrix sparse matrix to 'lda_c' format
#' @description Converts 'dgCMatrix' (or coercible to 'dgCMatrix') to 'lda_c' format
#' @param X Document-Term matrix
#' @export
as.lda_c = function(X) {
  # recieved matrix in lda_c format, but without class attribute
  if (class(X) == 'list' && all(vapply(X, function(x) is.matrix(x) && is.integer(x), FALSE)) ) {
    class(X) = "lda_c"
    return(X)
  }
  if (!inherits(X, "RsparseMatrix"))
    X = as( X, "RsparseMatrix")
  len = nrow(X)
  input_ids = rownames(X)
  m_lda_c = vector("list", len)
  for(i in seq_len(len)) {
    i_start = X@p[i] + 1L
    i_end = X@p[i + 1L]
    # normal path -
    if(i_start <= i_end) {
      i_range = i_start:i_end
      # print(i_range)
      m_lda_c[[i]] = rbind(X@j[i_range], as.integer(X@x[i_range]))
    } # case when document is empty!
    else {
      # print("skip")
      m = integer()
      dim(m) = c(2L, 0L)
      m_lda_c[[i]] = m
    }
  }
  names(m_lda_c) = input_ids
  class(m_lda_c) = 'lda_c'
  m_lda_c
}

to_lda_c = function(X) {
  .Deprecated("as.lda_c")
  as.lda_c(X)
}

rbind_dgTMatrix = function(...) {
  res = new('dgTMatrix')
  mat_list = list(...)

  ncols = vapply(mat_list, ncol, FUN.VALUE = 0L)
  stopifnot( length(unique(ncols)) == 1)

  all_colnames = lapply(mat_list, colnames)
  stopifnot( length(unique(all_colnames)) == 1)

  nrows = vapply(mat_list, nrow, FUN.VALUE = 0L)
  offset = cumsum(c(0L, nrows[-length(nrows)]))

  res@i = do.call(c, Map(function(m, offs) m@i + offs, mat_list, offset))

  res@j = do.call(c, lapply(mat_list, function(m) m@j) )
  res@x = do.call(c, lapply(mat_list, function(m) m@x) )
  res_rownames = do.call(c, lapply(mat_list, rownames) )

  res@Dim = c(sum(nrows), ncols[[1]])
  res@Dimnames = list(res_rownames, all_colnames[[1]] )
  res
}

#' @name split_into
#' @title Split a vector for parallel processing
#' @description This function splits a vector into \code{n} parts of roughly
#'   equal size. These splits can be used for parallel processing. In general,
#'   \code{n} should be equal to the number of jobs you want to run, which
#'   should be the number of cores you want to use.
#' @param vec input vector
#' @param n \code{integer} desired number of chunks
#' @return \code{list} with \code{n} elements, each of roughly equal length
#' @export
split_into = function(vec, n) {
  vec_len = length(vec)
  chunk_len = vec_len %/% n
  # number of vectrors of size (chunk_len + 1)
  n2 = (vec_len - chunk_len * n)
  if (n2 == 0) {
    split_factors = rep( 1:n, each = chunk_len)
  } else
    split_factors = c( rep( 1:n2, each = chunk_len + 1),
                        rep( (n2 + 1):n,  each = chunk_len))
  split(vec, split_factors)
}
