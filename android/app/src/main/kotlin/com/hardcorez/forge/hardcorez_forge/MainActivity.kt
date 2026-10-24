package com.hardcorez.forge.hardcorez_forge

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipFile

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hardcorez.forge/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasStoragePermission" -> {
                    val hasPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(hasPerm)
                }
                "requestStoragePermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val uri = Uri.parse("package:$packageName")
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, uri)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), 101)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "renderPdfPage" -> {
                    val path = call.argument<String>("path") ?: ""
                    val pageIndex = call.argument<Int>("pageIndex") ?: 0
                    val width = call.argument<Int>("width") ?: 1080
                    val data = renderPdfPage(path, pageIndex, width)
                    result.success(data)
                }
                "burnSignaturesToPdf" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val targetPath = call.argument<String>("targetPath") ?: ""
                    val signatures = call.argument<List<Map<String, Any>>>("signatures") ?: emptyList()
                    val title = call.argument<String>("title")
                    val content = call.argument<String>("content")
                    val ok = burnSignaturesToPdf(sourcePath, targetPath, signatures, title, content)
                    result.success(ok)
                }
                "shareFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    val title = call.argument<String>("title") ?: "Bagikan Berkas"
                    val ok = shareFile(path, title)
                    result.success(ok)
                }
                "openFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    val ok = openFile(path)
                    result.success(ok)
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val title = call.argument<String>("title") ?: "Bagikan Dokumen"
                    val sendIntent = Intent().apply {
                        action = Intent.ACTION_SEND
                        putExtra(Intent.EXTRA_TEXT, text)
                        type = "text/plain"
                    }
                    val shareIntent = Intent.createChooser(sendIntent, title)
                    startActivity(shareIntent)
                    result.success(true)
                }
                "extractDocxText" -> {
                    val path = call.argument<String>("path") ?: ""
                    val text = extractDocxText(path)
                    result.success(text)
                }
                "extractXlsxCells" -> {
                    val path = call.argument<String>("path") ?: ""
                    val data = extractXlsxCells(path)
                    result.success(data)
                }
                "extractPptxSlides" -> {
                    val path = call.argument<String>("path") ?: ""
                    val data = extractPptxSlides(path)
                    result.success(data)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun renderPdfPage(filePath: String, pageIndex: Int, targetWidth: Int = 1080): Map<String, Any>? {
        return try {
            val file = File(filePath)
            if (!file.exists()) return null
            val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            val renderer = PdfRenderer(pfd)
            val pageCount = renderer.pageCount
            if (pageCount == 0) {
                renderer.close()
                pfd.close()
                return null
            }
            val safeIndex = pageIndex.coerceIn(0, pageCount - 1)
            val page = renderer.openPage(safeIndex)

            val width = targetWidth
            val height = ((width.toFloat() / page.width) * page.height).toInt().coerceAtLeast(100)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(android.graphics.Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            page.close()
            renderer.close()
            pfd.close()

            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream)
            val bytes = stream.toByteArray()
            bitmap.recycle()

            mapOf(
                "pageCount" to pageCount,
                "pageIndex" to safeIndex,
                "bytes" to bytes
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun extractDocxText(filePath: String): String {
        return try {
            val file = File(filePath)
            if (!file.exists()) return ""
            val zip = ZipFile(file)

            val docxEntry = zip.getEntry("word/document.xml")
            val odtEntry = zip.getEntry("content.xml")
            val targetEntry = docxEntry ?: odtEntry ?: return ""
            val xml = zip.getInputStream(targetEntry).bufferedReader().use { it.readText() }
            zip.close()

            val sb = StringBuilder()
            if (docxEntry != null) {
                val paragraphs = xml.split("</w:p>")
                val tRegex = Regex("<w:t[^>]*>(.*?)</w:t>", RegexOption.DOT_MATCHES_ALL)
                for (p in paragraphs) {
                    val line = tRegex.findAll(p)
                        .map { it.groupValues[1] }
                        .joinToString("")
                        .replace("&amp;", "&")
                        .replace("&lt;", "<")
                        .replace("&gt;", ">")
                        .replace("&quot;", "\"")
                        .replace("&apos;", "'")
                        .trim()
                    if (line.isNotBlank()) {
                        sb.append(line).append("\n\n")
                    }
                }
            } else {

                val paragraphs = xml.split("</text:p>")
                val tagRegex = Regex("<[^>]+>")
                for (p in paragraphs) {
                    val cleanLine = tagRegex.replace(p, "").trim()
                        .replace("&amp;", "&")
                        .replace("&lt;", "<")
                        .replace("&gt;", ">")
                    if (cleanLine.isNotBlank()) {
                        sb.append(cleanLine).append("\n\n")
                    }
                }
            }
            sb.toString().trim()
        } catch (e: Exception) {
            ""
        }
    }

    private fun extractXlsxCells(filePath: String): Map<String, Any> {
        return try {
            val file = File(filePath)
            if (!file.exists()) return emptyMap()
            val zip = ZipFile(file)

            val sharedStrings = mutableListOf<String>()
            val ssEntry = zip.getEntry("xl/sharedStrings.xml")
            if (ssEntry != null) {
                val ssXml = zip.getInputStream(ssEntry).bufferedReader().use { it.readText() }
                val tRegex = Regex("<t[^>]*>(.*?)</t>")
                tRegex.findAll(ssXml).forEach {
                    sharedStrings.add(it.groupValues[1])
                }
            }

            val sheetEntry = zip.getEntry("xl/worksheets/sheet1.xml")
            if (sheetEntry != null) {
                val sheetXml = zip.getInputStream(sheetEntry).bufferedReader().use { it.readText() }
                zip.close()

                val cells = mutableMapOf<String, String>()
                var maxRow = 20
                var maxCol = 8

                val cellRegex = Regex("""<c\s+r="([A-Z]+)(\d+)"(?:\s+t="([a-z]+)")?[^>]*>(?:<v>([^<]*)</v>)?(?:<is><t>([^<]*)</t></is>)?""")
                cellRegex.findAll(sheetXml).forEach { match ->
                    val colLetter = match.groupValues[1]
                    val rowNum = match.groupValues[2].toIntOrNull() ?: 1
                    val type = match.groupValues[3]
                    val value = match.groupValues[4]
                    val inline = match.groupValues[5]

                    var displayVal = ""
                    if (type == "s") {
                        val idx = value.toIntOrNull() ?: -1
                        if (idx in sharedStrings.indices) {
                            displayVal = sharedStrings[idx]
                        }
                    } else if (inline.isNotEmpty()) {
                        displayVal = inline
                    } else {
                        displayVal = value
                    }

                    if (displayVal.isNotEmpty()) {
                        cells["$colLetter$rowNum"] = displayVal
                        if (rowNum > maxRow) maxRow = rowNum
                        val colIdx = colLetter[0] - 'A' + 1
                        if (colIdx > maxCol) maxCol = colIdx
                    }
                }

                mapOf(
                    "rows" to maxOf(maxRow + 5, 20),
                    "cols" to maxOf(maxCol + 2, 8),
                    "cells" to cells
                )
            } else {

                val odsEntry = zip.getEntry("content.xml") ?: return emptyMap()
                val xml = zip.getInputStream(odsEntry).bufferedReader().use { it.readText() }
                zip.close()

                val cells = mutableMapOf<String, String>()
                var rowIdx = 1
                var maxCol = 8
                val rowRegex = Regex("<table:table-row[^>]*>(.*?)</table:table-row>")
                val cellRegex = Regex("<table:table-cell[^>]*>(.*?)</table:table-cell>")
                val tagRegex = Regex("<[^>]+>")

                rowRegex.findAll(xml).forEach { rMatch ->
                    var colIdx = 1
                    cellRegex.findAll(rMatch.groupValues[1]).forEach { cMatch ->
                        val cellText = tagRegex.replace(cMatch.groupValues[1], "").trim()
                        if (cellText.isNotBlank() && colIdx <= 26) {
                            val colLetter = ('A'.code + colIdx - 1).toChar().toString()
                            cells["$colLetter$rowIdx"] = cellText
                            if (colIdx > maxCol) maxCol = colIdx
                        }
                        colIdx++
                    }
                    rowIdx++
                }

                mapOf(
                    "rows" to maxOf(rowIdx + 4, 20),
                    "cols" to maxOf(maxCol + 2, 8),
                    "cells" to cells
                )
            }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private fun extractPptxSlides(filePath: String): List<Map<String, Any>> {
        return try {
            val file = File(filePath)
            if (!file.exists()) return emptyList()
            val zip = ZipFile(file)
            val slideEntries = zip.entries().asSequence()
                .filter { it.name.matches(Regex("""ppt/slides/slide\d+\.xml""")) }
                .sortedBy {
                    Regex("""\d+""").find(it.name)?.value?.toIntOrNull() ?: 0
                }
                .toList()

            val slides = mutableListOf<Map<String, Any>>()
            val pRegex = Regex("<a:p[ >](.*?)</a:p>")
            val tRegex = Regex("<a:t[^>]*>(.*?)</a:t>")

            var slideThemeIdx = 0
            for (entry in slideEntries) {
                val xml = zip.getInputStream(entry).bufferedReader().use { it.readText() }
                val lines = mutableListOf<String>()
                pRegex.findAll(xml).forEach { p ->
                    val text = tRegex.findAll(p.groupValues[1]).map { it.groupValues[1] }.joinToString("").trim()
                    if (text.isNotBlank()) {
                        lines.add(text)
                    }
                }

                val title = if (lines.isNotEmpty()) lines[0] else "Slide ${slides.size + 1}"
                val subtitle = if (lines.size > 1 && lines[1].length < 60) lines[1] else ""
                val contentStart = if (subtitle.isNotEmpty()) 2 else 1
                val content = if (lines.size > contentStart) {
                    lines.subList(contentStart, lines.size).joinToString("\n• ", prefix = "• ")
                } else ""

                slides.add(
                    mapOf(
                        "title" to title,
                        "subtitle" to subtitle,
                        "content" to content,
                        "themeIndex" to (slideThemeIdx % 4)
                    )
                )
                slideThemeIdx++
            }
            zip.close()
            slides
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun burnSignaturesToPdf(
        sourcePath: String?,
        targetPath: String,
        signatures: List<Map<String, Any>>,
        documentTitle: String?,
        documentContent: String?
    ): Boolean {
        return try {
            val targetFile = File(targetPath)
            targetFile.parentFile?.mkdirs()

            val isReplacing = sourcePath != null &&
                    File(sourcePath).exists() &&
                    File(sourcePath).canonicalPath == targetFile.canonicalPath

            val tempFile = if (isReplacing) {
                File(targetFile.parentFile, "${targetFile.name}.tmp_${System.currentTimeMillis()}")
            } else {
                targetFile
            }

            val pdfDocument = PdfDocument()

            if (sourcePath != null && File(sourcePath).exists()) {
                val srcFile = File(sourcePath)
                val pfd = ParcelFileDescriptor.open(srcFile, ParcelFileDescriptor.MODE_READ_ONLY)
                val renderer = PdfRenderer(pfd)
                val pageCount = renderer.pageCount

                for (i in 0 until pageCount) {
                    val page = renderer.openPage(i)
                    val pw = page.width
                    val ph = page.height

                    val rw = (pw * 2).coerceAtLeast(720)
                    val rh = (ph * 2).coerceAtLeast(960)
                    val pageBitmap = Bitmap.createBitmap(rw, rh, Bitmap.Config.ARGB_8888)
                    pageBitmap.eraseColor(android.graphics.Color.WHITE)
                    page.render(pageBitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                    page.close()

                    val pageInfo = PdfDocument.PageInfo.Builder(pw, ph, i + 1).create()
                    val newPage = pdfDocument.startPage(pageInfo)
                    val canvas = newPage.canvas

                    val srcRect = Rect(0, 0, rw, rh)
                    val dstRect = RectF(0f, 0f, pw.toFloat(), ph.toFloat())
                    canvas.drawBitmap(pageBitmap, srcRect, dstRect, null)
                    pageBitmap.recycle()

                    val pageSigs = signatures.filter { (it["page"] as? Number)?.toInt() == (i + 1) }
                    for (sig in pageSigs) {
                        val relX = (sig["relX"] as? Number)?.toFloat() ?: 0f
                        val relY = (sig["relY"] as? Number)?.toFloat() ?: 0f
                        val relW = (sig["relW"] as? Number)?.toFloat() ?: 0.35f
                        val relH = (sig["relH"] as? Number)?.toFloat() ?: 0.15f

                        val sigX = relX * pw
                        val sigY = relY * ph
                        val sigW = relW * pw
                        val sigH = relH * ph
                        val sigRect = RectF(sigX, sigY, sigX + sigW, sigY + sigH)

                        val imgBytes = sig["imageBytes"] as? ByteArray
                        if (imgBytes != null && imgBytes.isNotEmpty()) {
                            val sigBitmap = BitmapFactory.decodeByteArray(imgBytes, 0, imgBytes.size)
                            if (sigBitmap != null) {
                                val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
                                canvas.drawBitmap(sigBitmap, null, sigRect, paint)
                                sigBitmap.recycle()
                            }
                        }
                    }

                    pdfDocument.finishPage(newPage)
                }

                renderer.close()
                pfd.close()
            } else {

                val pw = 595
                val ph = 842

                val maxSigPage = signatures.mapNotNull { (it["page"] as? Number)?.toInt() }.maxOrNull() ?: 1
                val totalPages = maxOf(maxSigPage, 1)

                val title = documentTitle ?: "Dokumen Resmi"
                val content = documentContent ?: ""

                for (pageIdx in 1..totalPages) {
                    val pageInfo = PdfDocument.PageInfo.Builder(pw, ph, pageIdx).create()
                    val page = pdfDocument.startPage(pageInfo)
                    val canvas = page.canvas

                    canvas.drawColor(android.graphics.Color.WHITE)

                    val paint = Paint(Paint.ANTI_ALIAS_FLAG)

                    paint.color = android.graphics.Color.parseColor("#0F172A")
                    paint.textSize = 10f
                    paint.isFakeBoldText = true
                    canvas.drawText("HARDCOREZFORGE OFFICIAL DOCUMENT", 40f, 45f, paint)

                    paint.color = android.graphics.Color.parseColor("#94A3B8")
                    paint.textSize = 9f
                    paint.isFakeBoldText = false
                    canvas.drawText("HLM $pageIdx / $totalPages", (pw - 85).toFloat(), 45f, paint)

                    paint.color = android.graphics.Color.parseColor("#E2E8F0")
                    paint.strokeWidth = 1f
                    canvas.drawLine(40f, 55f, (pw - 40).toFloat(), 55f, paint)

                    if (pageIdx == 1) {
                        paint.color = android.graphics.Color.parseColor("#0F172A")
                        paint.textSize = 16f
                        paint.isFakeBoldText = true
                        canvas.drawText(title, 40f, 85f, paint)

                        paint.color = android.graphics.Color.parseColor("#334155")
                        paint.textSize = 11f
                        paint.isFakeBoldText = false

                        val lines = content.split("\n")
                        var y = 115f
                        for (line in lines) {
                            if (y > ph - 120) break
                            canvas.drawText(line, 40f, y, paint)
                            y += 18f
                        }
                    }

                    paint.color = android.graphics.Color.parseColor("#E2E8F0")
                    canvas.drawLine(40f, (ph - 45).toFloat(), (pw - 40).toFloat(), (ph - 45).toFloat(), paint)

                    paint.color = android.graphics.Color.parseColor("#64748B")
                    paint.textSize = 8.5f
                    canvas.drawText("Status: Terverifikasi Digital • HardcorezForge Mobile Office", 40f, (ph - 30).toFloat(), paint)

                    val pageSigs = signatures.filter { (it["page"] as? Number)?.toInt() == pageIdx }
                    for (sig in pageSigs) {
                        val relX = (sig["relX"] as? Number)?.toFloat() ?: 0.1f
                        val relY = (sig["relY"] as? Number)?.toFloat() ?: 0.6f
                        val relW = (sig["relW"] as? Number)?.toFloat() ?: 0.35f
                        val relH = (sig["relH"] as? Number)?.toFloat() ?: 0.15f

                        val sigX = relX * pw
                        val sigY = relY * ph
                        val sigW = relW * pw
                        val sigH = relH * ph
                        val sigRect = RectF(sigX, sigY, sigX + sigW, sigY + sigH)

                        val imgBytes = sig["imageBytes"] as? ByteArray
                        if (imgBytes != null && imgBytes.isNotEmpty()) {
                            val sigBitmap = BitmapFactory.decodeByteArray(imgBytes, 0, imgBytes.size)
                            if (sigBitmap != null) {
                                val p = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
                                canvas.drawBitmap(sigBitmap, null, sigRect, p)
                                sigBitmap.recycle()
                            }
                        }
                    }

                    pdfDocument.finishPage(page)
                }
            }

            FileOutputStream(tempFile).use { fos ->
                pdfDocument.writeTo(fos)
            }
            pdfDocument.close()

            if (isReplacing) {
                if (targetFile.exists()) {
                    targetFile.delete()
                }
                tempFile.renameTo(targetFile)
            }

            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun shareFile(filePath: String, title: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val mimeType = getMimeType(filePath)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, title))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val mimeType = getMimeType(filePath)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Buka Berkas Dengan"))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun getMimeType(path: String): String {
        val ext = path.substringAfterLast('.', "").lowercase()
        return when (ext) {
            "pdf" -> "application/pdf"
            "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "doc" -> "application/msword"
            "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            "xls" -> "application/vnd.ms-excel"
            "pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            "ppt" -> "application/vnd.ms-powerpoint"
            "csv" -> "text/csv"
            "tsv" -> "text/tab-separated-values"
            "txt" -> "text/plain"
            "md" -> "text/markdown"
            else -> "*/*"
        }
    }
}
