from django.conf import settings
from django.core.management.base import BaseCommand

from users.models import User


DEFAULT_PASSWORD = 'Test@12345'


class Command(BaseCommand):
    help = 'Create one development login account for each application role.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--password',
            default=DEFAULT_PASSWORD,
            help='Password assigned to every seeded user.',
        )

    def handle(self, *args, **options):
        password = options['password']
        users = [
            ('direction@stca.tn', 'Direction', 'Admin', User.Role.DIRECTION),
            ('collecteur@stca.tn', 'Collecteur', 'Amine', User.Role.COLLECTEUR),
            ('degustateur@stca.tn', 'Degustateur', 'Salma', User.Role.DEGUSTATEUR),
            ('chef@stca.tn', 'Chef', 'Dégustation', User.Role.CHEF_DEGUSTATION),
        ]
        if settings.LABO_ACTIF:
            users.append(('labo@stca.tn', 'Laboratoire', 'Nour', User.Role.LABORATOIRE))

        for email, nom, prenom, role in users:
            user, created = User.objects.update_or_create(
                email=email,
                defaults={
                    'nom': nom,
                    'prenom': prenom,
                    'role': role,
                    'is_active': True,
                },
            )
            user.set_password(password)
            if role == User.Role.DIRECTION:
                user.is_staff = True
                user.is_superuser = True
            user.save()
            action = 'created' if created else 'updated'
            self.stdout.write(self.style.SUCCESS(f'{action}: {email} / {password}'))
