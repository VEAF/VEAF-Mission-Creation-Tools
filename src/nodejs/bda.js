// Generates a BDA in CSV format, based on the JSON stats saved by SLMOD
// 1. stop the mission on the server, and wait for SLMOD to generate the json file in "Slmod\Mission Stats"
// 2. copy the json file and rename it as "mission.json"
// 3. run the script
// 4. use the "mission.csv" file 

let _fs
try {
  _fs = require('graceful-fs')
} catch (_) {
  _fs = require('fs')
}
const universalify = require('universalify')

function stringify (obj, { EOL = '\n', finalEOL = true, replacer = null, spaces } = {}) {
  const EOF = finalEOL ? EOL : ''
  const str = JSON.stringify(obj, replacer, spaces)

  return str.replace(/\n/g, EOL) + EOF
}

function stripBom (content) {
  // we do this because JSON.parse would convert it to a utf8 string if encoding wasn't specified
  if (Buffer.isBuffer(content)) content = content.toString('utf8')
  return content.replace(/^\uFEFF/, '')
}

async function _readFile (file, options = {}) {
  if (typeof options === 'string') {
    options = { encoding: options }
  }

  const fs = options.fs || _fs

  const shouldThrow = 'throws' in options ? options.throws : true

  let data = await universalify.fromCallback(fs.readFile)(file, options)

  data = stripBom(data)

  let obj
  try {
    obj = JSON.parse(data, options ? options.reviver : null)
  } catch (err) {
    if (shouldThrow) {
      err.message = `${file}: ${err.message}`
      throw err
    } else {
      return null
    }
  }

  return obj
}

const readFile = universalify.fromPromise(_readFile)

function readFileSync (file, options = {}) {
  if (typeof options === 'string') {
    options = { encoding: options }
  }

  const fs = options.fs || _fs

  const shouldThrow = 'throws' in options ? options.throws : true

  try {
    let content = fs.readFileSync(file, options)
    content = stripBom(content)
    return JSON.parse(content, options.reviver)
  } catch (err) {
    if (shouldThrow) {
      err.message = `${file}: ${err.message}`
      throw err
    } else {
      return null
    }
  }
}

async function _writeFile (file, obj, options = {}) {
  const fs = options.fs || _fs

  const str = stringify(obj, options)

  await universalify.fromCallback(fs.writeFile)(file, str, options)
}

const writeFile = universalify.fromPromise(_writeFile)

function writeFileSync (file, obj, options = {}) {
  const fs = options.fs || _fs

  const str = stringify(obj, options)
  // not sure if fs.writeFileSync returns anything, but just in case
  return fs.writeFileSync(file, str, options)
}

const jsonfile = {
  readFile,
  readFileSync,
  writeFile,
  writeFileSync
}

function writeFileSync (file, str, options = {}) {
  const fs = options.fs || _fs

  // not sure if fs.writeFileSync returns anything, but just in case
  return fs.writeFileSync(file, str, options)
}

function toHHMMSS(val) {
  var sec_num = parseInt(val, 10); // don't forget the second param
  var hours   = Math.floor(sec_num / 3600);
  var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
  var seconds = sec_num - (hours * 3600) - (minutes * 60);

  if (hours   < 10) {hours   = "0"+hours;}
  if (minutes < 10) {minutes = "0"+minutes;}
  if (seconds < 10) {seconds = "0"+seconds;}
  return hours+':'+minutes+':'+seconds;
}

let json = jsonfile.readFileSync("mission.json")
var buffer1 = "pilote;appareil;en l'air;total" + "\n"
var buffer2 = "\n\n\n" + "pilote;appareil;type;détruits" + "\n"
for(let inFlightKey in json) {
  let inFlight = json[inFlightKey]
  let pilotName = inFlight.names[0]
  let inFlightData = inFlight.times
  for(let planeKey in inFlightData) {
    let data = inFlightData[planeKey]
    let inAir = toHHMMSS(data.inAir)
    let total = toHHMMSS(data.total)
    var str = pilotName + ";" + planeKey + ";" + inAir + ";" + total
    console.log(str)
    buffer1 += str + "\n"
    for(let killType in data.kills) {
      let kills = data.kills[killType]
      for(let kill in kills) {
        if (kill == "total") continue
        let killN = kills[kill]
        var str = pilotName + ";" + planeKey + ";" + kill + ";" + killN
        console.log(str)
        buffer2 += str + "\n"
      }
    }
  }
}
writeFileSync("mission.csv", buffer1 + buffer2)