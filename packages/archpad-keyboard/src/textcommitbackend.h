#pragma once

#include <QObject>
#include <QString>
#include <cstdint>
#include <cstddef>

namespace ArchPad {

enum class ContentPurpose {
    Normal = 0,
    Alpha = 1,
    Digits = 2,
    Number = 3,
    Phone = 4,
    Url = 5,
    Email = 6,
    Name = 7,
    Password = 8,
    Pin = 9,
    Date = 10,
    Time = 11,
    DateTime = 12,
    Terminal = 13
};

enum class ContentHintFlag {
    None = 0x0000,
    AutoCompletion = 0x0001,
    AutoCorrection = 0x0002,
    AutoCapitalization = 0x0004,
    LowerCase = 0x0008,
    UpperCase = 0x0010,
    TitleCase = 0x0020,
    HiddenText = 0x0040,
    SensitiveData = 0x0080,
    Latin = 0x0100,
    MultiLine = 0x0200
};
Q_DECLARE_FLAGS(ContentHints, ContentHintFlag)
Q_DECLARE_OPERATORS_FOR_FLAGS(ContentHints)

class TextCommitBackend : public QObject {
    Q_OBJECT

public:
    explicit TextCommitBackend(QObject *parent = nullptr) : QObject(parent) {}
    ~TextCommitBackend() override = default;

    // Backend availability and state
    virtual bool isAvailable() const = 0;
    virtual bool isActive() const = 0;
    virtual uint32_t currentSerial() const = 0;

    // Field purpose and surrounding context metadata
    virtual ContentPurpose contentPurpose() const = 0;
    virtual ContentHints contentHints() const = 0;
    virtual bool hasSurroundingText() const = 0;
    virtual size_t surroundingCursorBytes() const = 0;
    virtual size_t surroundingAnchorBytes() const = 0;
    virtual bool hasActiveSelection() const = 0;

    // Mutation requests
    virtual bool commitText(const QString &text) = 0;
    virtual bool replacePrevious(size_t beforeUtf8Bytes, const QString &newText) = 0;
    virtual bool deleteSurrounding(size_t beforeUtf8Bytes, size_t afterUtf8Bytes) = 0;

    // Safety checks
    bool isSensitiveField() const {
        ContentPurpose p = contentPurpose();
        return (p == ContentPurpose::Password || p == ContentPurpose::Pin ||
                contentHints().testFlag(ContentHintFlag::HiddenText) ||
                contentHints().testFlag(ContentHintFlag::SensitiveData));
    }

    bool isTerminalField() const {
        return contentPurpose() == ContentPurpose::Terminal;
    }

Q_SIGNALS:
    void activeChanged(bool active);
    void contentPurposeChanged(ContentPurpose purpose);
    void contentHintsChanged(ContentHints hints);
    void surroundingTextChanged(bool available, size_t cursorBytes, size_t anchorBytes);
    void stateReset();
};

} // namespace ArchPad
