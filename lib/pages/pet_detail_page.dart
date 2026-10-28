import 'package:petguardian/pages/messages/message_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../stuff/app_network_image.dart';

class PetDetailPage extends StatefulWidget {
  final String petId;
  final String imagePath;

  const PetDetailPage({super.key, required this.petId, required this.imagePath});

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  bool isFavorite = false;

  // Report / abuse-flag state.
  //
  // The report document lives at `reports/<petId>_<uid>`, so "one report per
  // user per pet" is enforced structurally by Firestore rather than by a
  // client-side check that could race. `_petTitle` / `_petOwnerUID` are
  // resolved from Firestore at report time so the moderator sees an accurate
  // listing reference (widget.imagePath is only the photo URL).
  bool _hasReported = false;
  bool _isSubmittingReport = false;

  // Adoption-application state.
  //
  // The application lives at `applications/<petId>_<uid>`, so "one
  // application per user per pet" is structural. An application can be
  // filed, then approved/declined by the owner or withdrawn by the
  // applicant; every transition is enforced by firestore.rules.
  bool _hasApplied = false;
  bool _isSubmittingApplication = false;

  /// Reason choices offered in the report dialog.
  static const List<String> _reportReasons = [
    'Misleading or fake listing',
    'Inappropriate content',
    'Suspected scam',
    'Animal mistreatment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    loadFavoriteStatus();
    _loadReportStatus();
    _loadApplicationStatus();
  }

  /// Checks whether the signed-in user already applied for this pet, so the
  /// apply action renders in its resolved (already-applied) state.
  Future<void> _loadApplicationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('applications')
        .doc('${widget.petId}_${user.uid}')
        .get();
    if (mounted) {
      setState(() => _hasApplied = doc.exists);
    }
  }

  /// Checks whether the signed-in user already filed a report for this pet, so
  /// the flag action can render in its resolved (already-reported) state.
  Future<void> _loadReportStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('reports')
        .doc('${widget.petId}_${user.uid}')
        .get();
    if (mounted) {
      setState(() => _hasReported = doc.exists);
    }
  }

  /// Opens the report reason picker and, on confirm, submits the report.
  Future<void> _openReportDialog() async {
    String? chosenReason;
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Report listing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why are you reporting this listing?'),
                const SizedBox(height: 8),
                // `RadioGroup` owns the selected value so the tiles do not use
                // the deprecated `groupValue` / `onChanged` pair.
                RadioGroup<String>(
                  groupValue: chosenReason,
                  onChanged: (value) =>
                      setDialogState(() => chosenReason = value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _reportReasons
                        .map(
                          (reason) => RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                            dense: true,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Extra detail (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosenReason == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && chosenReason != null) {
      await _submitReport(chosenReason!, detailsController.text);
    }
    detailsController.dispose();
  }

  /// Writes a single abuse report against this listing.
  Future<void> _submitReport(String reason, String details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showReportSnack('You must sign in to report a listing.', ok: false);
      return;
    }
    setState(() => _isSubmittingReport = true);
    try {
      // Resolve the real title and owner so the moderator triage copy is
      // accurate without a second read.
      final petDoc = await FirebaseFirestore.instance
          .collection('pets')
          .doc(widget.petId)
          .get();
      final data = petDoc.data();
      final title = data?['title']?.toString() ?? '';
      final ownerUID = data?['userUID']?.toString() ?? '';

      await FirebaseFirestore.instance
          .collection('reports')
          .doc('${widget.petId}_${user.uid}')
          .set({
        'petId': widget.petId,
        'reporterUID': user.uid,
        'reason': reason,
        'details': details.trim(),
        'status': 'open',
        'createdAt': DateTime.now().toUtc(),
        'petTitle': title,
        'ownerUID': ownerUID,
      });
      if (mounted) {
        setState(() => _hasReported = true);
      }
      _showReportSnack('Report received. Thank you.', ok: true);
    } catch (e) {
      debugPrint('Report failed: $e');
      _showReportSnack('Report could not be sent. Please try again.', ok: false);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReport = false);
      }
    }
  }

  void _showReportSnack(String message, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> loadFavoriteStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String currentUserUID = user.uid;

      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUID)
          .collection('favorites')
          .doc(widget.petId)
          .get();

      isFavorite = docSnapshot.exists;
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Adds or removes this pet from the signed-in user's favorites.
///
/// [pet] carries the fields that are denormalised into the favorite document.
/// The optimistic UI update is reverted if the write fails, so the toggle never
/// shows a state that Firestore does not have.
Future<bool> toggleFavoriteStatus(
  bool value, {
  required String serialNumber,
  required String imagePath,
  required String title,
  required String kinds,
}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.petId);

    try {
      if (value) {
        await favoriteRef.set({
          'serialNumber': serialNumber,
          'imagePath': imagePath,
          'title': title,
          'Kinds': kinds,
          'timestamp': DateTime.now().toUtc(),
        });
      } else {
        await favoriteRef.delete();
      }
      return true;
    } catch (e) {
      debugPrint('Favori güncellenirken hata oluştu: $e');
      if (mounted) {
        // Revert: the toggle must not claim a change that was not persisted.
        setState(() => isFavorite = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'Favorilere eklenemedi.'
                : 'Favorilerden çıkarılamadı.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }



  /// Opens the adoption-application dialog and, on confirm, submits the
  /// application. [petTitle] / [ownerUID] come from the already-loaded pet
  /// document, so no second read is needed.
  Future<void> _openApplicationDialog({
    required String petTitle,
    required String ownerUID,
  }) async {
    final messageController = TextEditingController();
    final phoneController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Sahiplenme Başvurusu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$petTitle için sahiplendirme başvurusu gönderin. '
                  'İlan sahibi başvurunuzu onaylayabilir veya reddedebilir.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLength: 1000,
                  maxLines: 4,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Neden uygun bir yuva olursunuz?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Telefon (opsiyonel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: messageController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Başvuruyu Gönder'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _submitApplication(
      message: messageController.text.trim(),
      phone: phoneController.text.trim(),
      petTitle: petTitle,
      ownerUID: ownerUID,
    );
  }

  Future<void> _submitApplication({
    required String message,
    required String phone,
    required String petTitle,
    required String ownerUID,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSubmittingApplication) return;
    setState(() => _isSubmittingApplication = true);
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc('${widget.petId}_${user.uid}')
          .set({
        'petId': widget.petId,
        'applicantUID': user.uid,
        'ownerUID': ownerUID,
        'petTitle': petTitle,
        'message': message,
        if (phone.isNotEmpty) 'phone': phone,
        'status': 'pending',
        'createdAt': DateTime.now().toUtc(),
      });
      if (mounted) {
        setState(() => _hasApplied = true);
      }
      _showReportSnack('Başvurunuz iletildi. İlan sahibi inceleyecek.', ok: true);
    } catch (e) {
      debugPrint('Başvuru gönderilemedi: $e');
      _showReportSnack('Başvuru gönderilemedi. Lütfen tekrar deneyin.', ok: false);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingApplication = false);
      }
    }
  }

  /// Owner view: every application filed for this pet, newest first, with
  /// approve/decline actions on pending ones.
  void _openApplicationsSheet(String petId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('applications')
                .where('petId', isEqualTo: petId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snapshot.data?.docs ?? const [];
              return SizedBox(
                height: 480,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Başvurular (${docs.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      child: docs.isEmpty
                          ? Center(
                              child: Text(
                                'Henüz başvuru yok.',
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final d = docs[i].data();
                                final status = d['status']?.toString() ?? 'pending';
                                final message = d['message']?.toString() ?? '';
                                final phone = d['phone']?.toString() ?? '';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                message,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            _applicationStatusChip(status, scheme),
                                          ],
                                        ),
                                        if (phone.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone,
                                                size: 14,
                                                color: scheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                phone,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (status == 'pending') ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _resolveApplication(
                                                  docs[i].id,
                                                  'declined',
                                                ),
                                                icon: const Icon(Icons.close),
                                                label: const Text('Reddet'),
                                              ),
                                              const SizedBox(width: 8),
                                              FilledButton.icon(
                                                onPressed: () =>
                                                    _resolveApplication(
                                                  docs[i].id,
                                                  'approved',
                                                ),
                                                icon: const Icon(Icons.check),
                                                label: const Text('Onayla'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _resolveApplication(String docId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(docId)
          .update({
        'status': status,
        'resolvedAt': DateTime.now().toUtc(),
        'resolvedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      _showReportSnack(
        status == 'approved' ? 'Başvuru onaylandı.' : 'Başvuru reddedildi.',
        ok: true,
      );
    } catch (e) {
      debugPrint('Başvuru güncellenemedi: $e');
      _showReportSnack('Başvuru güncellenemedi.', ok: false);
    }
  }

  Widget _applicationStatusChip(String status, ColorScheme scheme) {
    final (String label, Color bg, Color fg) = switch (status) {
      'pending' => ('Bekliyor', scheme.tertiaryContainer, scheme.onTertiaryContainer),
      'approved' => ('Onaylandı', scheme.primaryContainer, scheme.onPrimaryContainer),
      'declined' => ('Reddedildi', scheme.errorContainer, scheme.onErrorContainer),
      'withdrawn' => ('Geri çekildi', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      _ => (status, scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('pets').doc(widget.petId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pets,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Evcil Hayvan Bilgileri',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.pets,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Theme.of(context).colorScheme.onPrimary,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.data() == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pets,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Evcil Hayvan Bilgileri',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.pets,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Theme.of(context).colorScheme.onPrimary,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            body: const Center(
              child: Text('Hayvan bilgisi bulunamadı.'),
            ),
          );
        } else {
          var data = snapshot.data!.data()!;
          String serialNumber = data['serialNumber']?.toString() ?? 'Bilgi yok';
          String age = data['age']?.toString() ?? 'Bilgi yok';
          String recipientUID = data['userUID']?.toString() ?? 'Bilgi yok';
          String imagePath = data['imagePath']?.toString() ?? 'Bilgi yok';
          String title = data['title']?.toString() ?? 'Bilgi yok';
          String gender = data['gender']?.toString() ?? 'Bilgi yok';
          String type = data['type']?.toString() ?? 'Bilgi yok';
          String phone = data['phone']?.toString() ??
              'Bilgi yok'; // Telefon numarasını alın
          String kinds = data['Kinds']?.toString() ??
              'Bilgi yok'; // Tür alın
          String adoption = data['adoption']?.toString() ??
              'Bilgi yok'; // SAhiplendirme durumun alın
          String chip = data['chip']?.toString() ??
              'Bilgi yok'; // çip numarasını alın
          String vaccine = data['vaccine']?.toString() ??
              'Bilgi yok'; // aşı numarasını alın
          // Extract placemark data
          var placemarkData = data['placemark'] as Map<String, dynamic>?;
          String locality = placemarkData?['locality']?.toString() ?? 'Bilgi yok';
          String administrativeArea = placemarkData?['administrativeArea']?.toString() ?? 'Bilgi yok';
          String country = placemarkData?['country']?.toString() ?? 'Bilgi yok';

          return Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pets,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Evcil Hayvan Bilgileri',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.pets,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Theme.of(context).colorScheme.onPrimary,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              actions: [
                IconButton(
                  icon: AnimatedScale(
                    // Little "pop" when the heart fills; settles back when it
                    // empties. Keyed by state so the scale re-runs each toggle.
                    key: ValueKey<bool>(isFavorite),
                    scale: isFavorite ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: isFavorite ? Curves.easeOutBack : Curves.easeOut,
                    child: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onPressed: () async {
                    final newValue = !isFavorite;
                    setState(() {
                      isFavorite = newValue;
                    });
                    // Single source of truth: this writes the favorite once.
                    // A failure reverts the optimistic update.
                    await toggleFavoriteStatus(
                      newValue,
                      serialNumber: serialNumber,
                      imagePath: imagePath,
                      title: title,
                      kinds: kinds,
                    );
                  },
                ),
                IconButton(
                  tooltip: _hasReported
                      ? 'You reported this listing'
                      : 'Report this listing',
                  icon: Icon(
                    _hasReported ? Icons.flag : Icons.flag_outlined,
                    color: _hasReported
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _hasReported || _isSubmittingReport
                      ? null
                      : _openReportDialog,
                ),
              ],

              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    _buildInfoItem('Seri Numarası', serialNumber),
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Hero(
                        // Same tag as the feed thumbnail: the photo grows
                        // out of the tapped card instead of popping in.
                        tag: 'pet-image-${widget.petId}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppNetworkImage(
                            url: imagePath,
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '$locality $administrativeArea $country',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
                    const SizedBox(height: 16),
                    _buildInfoItem('Yaş', age),
                    _buildInfoItem('Cinsiyet', gender),
                    _buildInfoItem('Tür', type),
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      // Fetch the user's data using recipientUID
                      future: FirebaseFirestore.instance.collection('users').doc(recipientUID).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (userSnapshot.hasError) {
                          return const Text('Kullanıcı verileri alınırken bir hata oluştu.');
                        } else if (!userSnapshot.hasData || userSnapshot.data!.data() == null) {
                          return const Text('Kullanıcı verileri bulunamadı.');
                        } else {
                          var userData = userSnapshot.data!.data()!;
                          String ownerFullName = userData['fullName']?.toString() ?? 'Bilgi yok';

                          return _buildInfoItem('Hayvan Sahibi', ownerFullName);
                        }
                      },
                    ),
                    _buildInfoItem('Telefon Numarası', phone),
                    _buildInfoItem('Hayvan Türü', kinds),
                    _buildInfoItem('Sahiplenme Durumu', adoption),
                    _buildInfoItem('Çip Durumu', chip),
                    _buildInfoItem('Aşı Durumu', vaccine),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // `phone` falls back to 'Bilgi yok' when the pet has no
                        // number, which must not be dialled.
                        if (phone.isEmpty || phone == 'Bilgi yok') {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bu ilan için telefon numarası yok.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final call = Uri(scheme: 'tel', path: phone);
                        var launched = false;
                        try {
                          launched = await launchUrl(call);
                        } catch (e) {
                          debugPrint('Arama başlatılamadı: $e');
                        }

                        if (launched || !context.mounted) return;
                        // Throwing here used to crash the screen; show the number
                        // so the user can still dial it manually.
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Arama uygulaması açılamadı. Numara: $phone'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.call),
                          SizedBox(width: 8),
                          Text('Ara'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Giriş yapan kullanıcının UID'sini alın
                        User? user = FirebaseAuth.instance.currentUser;
                        String currentUserUID = user?.uid ?? ''; // UID veya boş bir değer

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MessagePage(
                              recipientUID: recipientUID,
                              currentUserUID: currentUserUID,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.message),
                          SizedBox(width: 8),
                          Text('Mesaj Gönder'),
                        ],
                      ),
                    ),
                    if (recipientUID !=
                        (FirebaseAuth.instance.currentUser?.uid ?? '')) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _hasApplied || _isSubmittingApplication
                            ? null
                            : () => _openApplicationDialog(
                                  petTitle: title,
                                  ownerUID: recipientUID,
                                ),
                        icon: Icon(
                          _hasApplied
                              ? Icons.check_circle
                              : Icons.volunteer_activism,
                        ),
                        label: Text(
                          _hasApplied
                              ? 'Başvurunuz Alındı'
                              : 'Sahiplenmek İstiyorum',
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _openApplicationsSheet(widget.petId),
                        icon: const Icon(Icons.group),
                        label: const Text('Başvurular'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
