import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET;

function extractTokenFromHeader(req, res) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({
            message: "Authorization header missing or malformed",
        });
    }
    const token = authHeader.split(" ")[1];
    return token;
};

export const validateAccess = (req, res, next) => {
    const token = extractTokenFromHeader(req, res);
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        return res.status(401).json({
            message: "Invalid or expired token",
        });
    }
};

export const validateDirectorAccess = (req, res, next) => {
    const token = extractTokenFromHeader(req, res);
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded.role !== "director") {
            return res.status(403).json({
                message: "Access denied. Director privileges required.",
            });
        }
        req.user = decoded;
        next();
    } catch (err) {
        return res.status(401).json({
            message: "Invalid or expired token",
        });
    }
};

export const validateActorAccess = (req, res, next) => {
    const token = extractTokenFromHeader(req, res);
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded.role !== "actor") {
            return res.status(403).json({
                message: "Access denied. Actor privileges required.",
            });
        }
        req.user = decoded;
        next();
    } catch (err) {
        return res.status(401).json({
            message: "Invalid or expired token",
        });
    }
};