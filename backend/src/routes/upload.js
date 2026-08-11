const express = require('express');
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
const sharp = require('sharp');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

const uploadDir = process.env.UPLOAD_DIR || 'uploads';
const uploadDirAbsolute = path.join(__dirname, '..', '..', uploadDir);
const maxFileSizeMb = parseInt(process.env.MAX_FILE_SIZE_MB || '8', 10);

const MAX_WIDTH = 1600;
const JPEG_QUALITY = 78;

const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: maxFileSizeMb * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_TYPES.has(file.mimetype)) {
      return cb(new Error('Only JPG, PNG, WEBP, or HEIC images are allowed'));
    }
    cb(null, true);
  },
});

// POST /api/upload  (multipart/form-data, field name: "images", up to 8 files)
router.post('/', authenticate, upload.array('images', 8), async (req, res) => {
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ error: 'No images uploaded' });
  }

  try {
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const urls = await Promise.all(
      req.files.map(async (file) => {
        const filename = `${Date.now()}-${crypto.randomBytes(8).toString('hex')}.jpg`;
        const outPath = path.join(uploadDirAbsolute, filename);

        await sharp(file.buffer)
          .rotate()
          .resize({ width: MAX_WIDTH, withoutEnlargement: true })
          .jpeg({ quality: JPEG_QUALITY, mozjpeg: true })
          .toFile(outPath);

        return `${baseUrl}/uploads/${filename}`;
      })
    );

    res.status(201).json({ urls });
  } catch (err) {
    console.error('Image processing failed:', err);
    res.status(400).json({ error: 'Could not process one or more images. Try a different photo.' });
  }
});

router.use((err, _req, res, _next) => {
  if (err instanceof multer.MulterError || err) {
    return res.status(400).json({ error: err.message || 'Upload failed' });
  }
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = router;