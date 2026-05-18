import PDFDocument from 'pdfkit';

export const createScriptPDF = (res, audition) => {
    // --- PDF Generation ---
    const doc = new PDFDocument({ margin: 50 });
    
    // Set response headers so the browser/client treats it as a downloadable PDF
    const safeTitle = audition.title.replace(/[^a-z0-9]/gi, "_").concat("_script").toLowerCase();
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", `attachment; filename="${safeTitle}.pdf"`);
    
    doc.pipe(res);
  // --- Main Title ---
  doc
    .fontSize(24)
    .font("Helvetica-Bold")
    .text(`${audition.title} - Script`, { align: "center" })
    .moveDown(1.5);
 
  // --- Script Lines ---
  doc.fontSize(12).font("Helvetica");
 
  for (const senctence of audition.script) {
    doc
      .font("Helvetica-Bold")
      .text(`(${senctence.emotion}): `, { continued: true })
      .font("Helvetica")
      .text(senctence.content)
      .moveDown(0.5);
  }
 
  doc.end();
}