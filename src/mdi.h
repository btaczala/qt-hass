#ifndef MDI_H
#define MDI_H

#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Resolves Material Design Icons names to the glyphs of the bundled webfont.
//
// Names arrive as strings from Home Assistant ("mdi:lightbulb-on"), so the lookup
// has to happen at runtime. Aliases are part of the table -- HA sends them, and
// they exist only in MDI's metadata.
class Mdi : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_SINGLETON

  // The family name the font actually registered under; never hardcode it.
  Q_PROPERTY(QString fontFamily READ fontFamily CONSTANT)
  Q_PROPERTY(QString version READ version CONSTANT)

public:
  static Mdi *create(QQmlEngine *, QJSEngine *);

  explicit Mdi(QObject *parent = nullptr);

  QString fontFamily() const noexcept { return font_family_; }
  QString version() const;

  // Accepts "mdi:lightbulb-on" or a bare "lightbulb-on". An empty name yields an
  // empty string; an unknown one yields the fallback glyph and warns once.
  Q_INVOKABLE QString glyph(const QString &name) const;

  Q_INVOKABLE bool hasIcon(const QString &name) const;

private:
  QString font_family_;
  mutable QSet<QString> warned_names_;
};

#endif // !MDI_H
