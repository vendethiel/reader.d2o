String::titleize = -> "#{@slice 0 1 .to-upper-case!}#{@slice 1 .to-lower-case!}"
require! <[fs]>
format = JSON.stringify _, null, '\t'
d = -> console.log format it

unless file = process.argv.2
	e "Usage : #{process.argv.1} file"

console.log "Processing #file"

class BigEndianReader
	(@buffer, @offset = 0) ->

	for [name, type, size] in [
		* 'Double' 'DoubleBE' 8
		* 'Int'    'Int32BE'  4
		* 'Uint'   'UInt32BE' 4
		* 'Short'  'Int16BE'  2
	] then let type, size
		::"read#name" = -> @read type, size

	read-utf: -> @sl @read-short! .to-string!
	
	read-utf-bytes: -> @sl it .to-string!

	read-bool: -> @sl 1 .to-string! is '\01'


	seek: (@offset) ->

	skip: (@offset +=)


	#D2O aliases
	read-i18n: -> @read-int!
	
	read-string: -> @read-utf!

	read-list: (field, dim = 0) ->
		i = 0; count = @read-int!

		while i < count, ++i
			type = field.vector-types[dim]type
			if type > 0 #class
				if classes[@read-int! - 1] #class-id, starts at 0
					build-object that
				else null
			else
				@"read#{type.titleize!}" field, dim + 1


	#private methods
	read: (type, size) ->
		v = @buffer"read#type" @offset
		@offset += size
		v

	sl: ->
		v = @buffer.slice @offset, @offset + it
		@offset += it
		v



buffer = new BigEndianReader fs.read-file-sync "data/#file.d2o"

unless 'D2O' is buffer.read-utf-bytes 3
	e 'Invalid file'

D2OFieldType =
	'-1': 'Int'
	'-2': 'Bool'
	'-3': 'String'
	'-4': 'Double'
	'-5': 'I18N'
	'-6': 'UInt'
	'-99': 'List'

#read indexes
buffer.seek buffer.read-int! #go to index-table
index-table-size = buffer.read-int!

i = 0
index-table = {[buffer.read-int!, buffer.read-int!] while i < index-table-size / 8, ++i}

add-vector = ->
	with it.push name: buffer.read-utf!, type: D2OFieldType[t = buffer.read-int!] ? t
		add-vector it if ..[*-1].type is 'List' #recursive

classes = []
classes-size = buffer.read-int!

i = 0
while i < classes-size, ++i
	c-id = buffer.read-int! #class id
	c = member-name: buffer.read-utf!, package-name: buffer.read-utf!
	field-count = buffer.read-int!

	field-i = 0
	# read fields
	c.fields = while field-i < field-count, ++field-i #build each field
		name: buffer.read-utf!, type: t = D2OFieldType[t = buffer.read-int!] ? t,\
			vector-types: t is 'List' and add-vector []

	classes[c-id - 1] = c #starts at 0

fs.write-file "extracted/fields/#file.json" format classes

#finally, build objects
objects = for , obj-index of index-table
	buffer.seek obj-index

	build-object classes[buffer.read-int! - 1] #class-id, starts at 0

function build-object({fields})
	{[name,
		if type > 0
			c-id = buffer.read-int!
			if classes[c-id - 1]
				build-object that #starts at 0
		else
			buffer"read#{type.titleize!}" field
	] for {type, name}:field in fields}

fs.write-file "extracted/#file.json" format objects

function e then console.log ...; process.exit!
