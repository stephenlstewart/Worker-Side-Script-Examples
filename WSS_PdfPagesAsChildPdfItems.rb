java_import java.io.FileOutputStream
java_import com.itextpdf.text.Document
java_import com.itextpdf.text.pdf.PdfCopy
java_import com.itextpdf.text.pdf.PdfReader

$pdf_mime_types = {
	"application/pdf" => true,
	"application/pdf-mail" => true,
	"application/pdf-portfolio" => true,
}

$temp_directory = "D:\\temp\\WssPdfTemp"

# Splits a source item (which is a PDF) into a series of PDFs, 1 per
# page in the source PDF.
def split_pdf_source_item(source_item,export_directory)
	generated_files = []
	java.io.File.new(export_directory).mkdirs
	input_stream = source_item.getBinary.getBinaryData.getInputStream
	reader = PdfReader.new(input_stream)
	base_name = File.basename(source_item.getLocalisedName,".pdf")
	pages = reader.getNumberOfPages
	pages.times do |page_number|
		page_number += 1
		output_file = File.join(export_directory,"#{base_name}_Page#{page_number.to_s.rjust(4,"0")}.pdf")
		document = Document.new(reader.getPageSizeWithRotation(page_number))
		writer = PdfCopy.new(document,FileOutputStream.new(output_file))
		document.open
		page = writer.getImportedPage(reader,page_number)
		writer.addPage(page)
		document.close
		writer.close
		generated_files << output_file
	end
	reader.close
	return generated_files
end

# Define our initialization callback
def nuix_worker_item_callback_init
	# Perform some setup here
end

# Define our worker item callback
def nuix_worker_item_callback(worker_item)
	source_item = worker_item.getSourceItem
	mime_type = source_item.getType.getName
	parent_source_item = source_item.getParent
	parent_mime_type = nil
	if parent_source_item.nil? == false
		parent_mime_type = parent_source_item.getType.getName
	end
	guid = worker_item.getItemGuid

	# If the mime type of the current item is a PDF one and the parent is not a PDF mime type
	# then we proceed to split it up.  We check this because later on the single page PDFs
	# we generate will pass through this callback and we don't want the logic to try and split
	# them again, which would result in a sort of recursive looping
	if $pdf_mime_types[mime_type] == true && (parent_mime_type.nil? || !$pdf_mime_types[parent_mime_type])
		puts "Splitting PDF: #{guid}"
		export_directory = File.join($temp_directory,guid)
		java.io.File.new(export_directory).mkdirs
		generated_files = split_pdf_source_item(source_item,export_directory)
		worker_item.setChildren(generated_files)
	end
end

# Define our closing callback
def nuix_worker_item_callback_close
	# Delete any temporary PDFs we created
	org.apache.commons.io.FileUtils.deleteDirectory(java.io.File.new($temp_directory))
end