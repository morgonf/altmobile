/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// Помощник KAuth от root для страницы «Хранилище»: cleanpackages удаляет
// скачанные пакеты apt (apt-get clean). Установленные программы это не
// затрагивает, пакеты при нужде скачиваются снова.

#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

#include <QProcess>

class StorageHelper : public QObject
{
    Q_OBJECT

public Q_SLOTS:
    KAuth::ActionReply cleanpackages(const QVariantMap &args);
};

KAuth::ActionReply StorageHelper::cleanpackages(const QVariantMap &)
{
    QProcess p;
    p.setProcessChannelMode(QProcess::MergedChannels);
    p.start(QStringLiteral("/usr/bin/apt-get"), {QStringLiteral("clean")});
    if (!p.waitForFinished(120000) || p.exitStatus() != QProcess::NormalExit || p.exitCode() != 0) {
        auto reply = KAuth::ActionReply::HelperErrorReply();
        const QString out = QString::fromUtf8(p.readAll()).trimmed();
        reply.setErrorDescription(out.isEmpty() ? QStringLiteral("apt-get clean завершился с ошибкой") : out);
        return reply;
    }
    return KAuth::ActionReply::SuccessReply();
}

KAUTH_HELPER_MAIN("org.altmobile.storage", StorageHelper)

#include "storagehelper.moc"
