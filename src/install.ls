require! {
  ncp.ncp
  path.join
  './extract'
  './download'
  events.EventEmitter
}
{ rm, mk, next, write, read, is-win, is-array, replace-env-vars, is-file, is-url, is-dir, clone, extend, tmpdir, discover-pkg } = require './utils'

const defaults =
  gzip: yes
  dest: null
  clean: yes
  save: no
  save-dev: no
  save-peer: no

module.exports = install = (options) ->
  { path, url, dest, clean } = options = options |> apply
  emitter = new EventEmitter
  output = null
  pkg-info = {}
  tmp = tmpdir!

  clean-dir = ->
    try
      rm tmp if tmp |> is-dir
      rm output if clean and output

  on-error = (err, code, cmd) ->
    clean-dir!
    err |> emitter.emit 'error', _, code, cmd

  on-entry = (entry) ->
    entry |> emitter.emit 'entry', _ if entry

  on-download = ->
    'download' |> emitter.emit

  on-progress = ->
    it |> emitter.emit 'progress', _

  on-archive = ->
    pkg-info := it
    it |> emitter.emit 'archive', _

  on-download-end = ->
    it |> emitter.emit 'downloadEnd', _

  on-end = (output) ->
    options |> save
    clean-dir!
    output |> emitter.emit 'end', _, options

  on-extract = ->
    if options.dest is tmp
      copy!
    else
      it |> on-end

  copy = ->
    dest = join process.cwd!, 'node_modules', (pkg-info.name or 'pkg')
    mk dest unless dest |> is-dir
    ncp tmp, dest, (err) ->
      return err |> on-error if err
      { dest } |> on-end

  extractor = (path) ->
    'start' |> emitter.emit
    options <<< { path }
    options.dest ||= tmp
    (options |> extract)
      .on 'error', on-error
      .on 'entry', on-entry
      .on 'archive', on-archive
      .on 'end', on-extract

  downloader = ->
    options.url = path unless url
    (options |> download)
      .on 'download', on-download
      .on 'progress', on-progress
      .on 'error', on-error
      .on 'end', ->
        output := it
        output |> on-download-end
        output |> extractor

  do-install = -> next ->
    if url or (path |> is-url)
      downloader!
    else
      path |> extractor

  try
    do-install!
  catch
    "Cannot install archive: #{e}" |> on-error
  emitter

apply = (options) ->
  (options |> extend (defaults |> clone), _)

save = (options) ->
  { save, save-dev, save-peer } = options
  pkg-path = discover-pkg!

  if pkg-path
    pkg = pkg-path |> read
    pkg-info = join options.dest, '.nar.json' |> read
    { manifest: { name, version } } = pkg-info

    if name and version
      if save
        pkg.dependencies ||= {}
        pkg.dependencies <<< (name): "~#{version}" unless pkg.dependencies[name]
      if save-dev
        pkg.dev-dependencies ||= {}
        pkg.dev-dependencies <<< (name): "~#{version}" unless pkg.dev-dependencies[name]
      if save-peer
        pkg.peer-dependencies ||= {}
        pkg.peer-dependencies <<< (name): "~#{version}" unless pkg.peer-dependencies[name]

  pkg |> write-json pkg-path, _

write-json = (path, pkg) ->
  pkg |> JSON.stringify _, null, 2 |> write path, _
