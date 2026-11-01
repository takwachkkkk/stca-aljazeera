from django.db import migrations, models
from django.db.models import F


def dater_les_achats_existants(apps, schema_editor):
    # La vraie date n'a jamais ete gardee : updated_at en est la meilleure
    # approximation pour les achats deja confirmes.
    Echantillon = apps.get_model('echantillons', 'Echantillon')
    Echantillon.objects.filter(
        statut_collecteur='achat_confirme',
        date_achat_confirme__isnull=True,
    ).update(date_achat_confirme=F('updated_at'))


class Migration(migrations.Migration):

    dependencies = [
        ('echantillons', '0017_facturation'),
    ]

    operations = [
        migrations.AddField(
            model_name='echantillon',
            name='date_achat_confirme',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.RunPython(dater_les_achats_existants, migrations.RunPython.noop),
    ]
