/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// Помощник KAuth от root для страницы «Доступ по SSH». set включает
// sshd сразу и при загрузке (или выключает), status читает действующие
// настройки сервера (sshd -T), которые пользователю не видны: каталог
// /etc/openssh закрыт.

#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

#include <QProcess>
#include <QStringList>

class SshHelper : public QObject
{
    Q_OBJECT

public Q_SLOTS:
    KAuth::ActionReply set(const QVariantMap &args);
    KAuth::ActionReply status(const QVariantMap &args);
};

static KAuth::ActionReply errorReply(const QString &text)
{
    auto reply = KAuth::ActionReply::HelperErrorReply();
    reply.setErrorDescription(text);
    return reply;
}

static int run(const QString &program, const QStringList &args, QString *out = nullptr)
{
    QProcess p;
    p.setProcessChannelMode(QProcess::MergedChannels);
    p.start(program, args);
    if (!p.waitForFinished(30000)) {
        return -1;
    }
    if (out) {
        *out = QString::fromUtf8(p.readAll());
    }
    return p.exitStatus() == QProcess::NormalExit ? p.exitCode() : -1;
}

KAuth::ActionReply SshHelper::set(const QVariantMap &args)
{
    const bool enable = args.value(QStringLiteral("enabled")).toBool();
    QString out;
    const int rc = run(QStringLiteral("/bin/systemctl"),
                       {enable ? QStringLiteral("enable") : QStringLiteral("disable"), QStringLiteral("--now"), QStringLiteral("sshd.service")},
                       &out);
    if (rc != 0) {
        return errorReply(out.trimmed().isEmpty() ? QStringLiteral("systemctl завершился с ошибкой") : out.trimmed());
    }
    return KAuth::ActionReply::SuccessReply();
}

KAuth::ActionReply SshHelper::status(const QVariantMap &)
{
    QString out;
    if (run(QStringLiteral("/usr/sbin/sshd"), {QStringLiteral("-T")}, &out) != 0) {
        return errorReply(QStringLiteral("sshd -T: настройки не прочитаны"));
    }
    QVariantMap data;
    const auto lines = out.split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        const QString key = line.section(QLatin1Char(' '), 0, 0);
        const QString value = line.section(QLatin1Char(' '), 1);
        if (key == QLatin1String("passwordauthentication") || key == QLatin1String("kbdinteractiveauthentication")
            || key == QLatin1String("permitrootlogin") || key == QLatin1String("port")) {
            data.insert(key, value);
        }
    }
    auto reply = KAuth::ActionReply::SuccessReply();
    reply.setData(data);
    return reply;
}

KAUTH_HELPER_MAIN("org.altmobile.ssh", SshHelper)

#include "sshhelper.moc"
