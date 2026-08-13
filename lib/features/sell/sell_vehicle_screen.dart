import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/providers/auth_provider.dart';
import '../../services/providers/vehicle_providers.dart';
import '../../services/repositories/vehicle_service.dart';
import '../../widgets/app_image.dart';

class SellVehicleScreen extends ConsumerStatefulWidget {
  /// When null, this is the "Sell" tab (create a new listing). When set,
  /// this is a pushed page for editing that existing listing instead.
  final String? editVehicleId;

  const SellVehicleScreen({super.key, this.editVehicleId});

  @override
  ConsumerState<SellVehicleScreen> createState() => _SellVehicleScreenState();
}

class _SellVehicleScreenState extends ConsumerState<SellVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _originalPriceCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _category = 'Cars';
  String _fuelType = 'Petrol';
  String _transmission = 'Manual';
  String _owners = '1 Owner';
  String _condition = 'Good';
  String _insuranceStatus = 'Valid';
  DateTime? _insuranceExpiry;
  String _rcStatus = 'Clear';
  bool _submitting = false;
  bool _uploadingPhotos = false;
  final List<File> _pickedImages = [];

  // Photos the listing already had (only populated in edit mode). Kept
  // separate from _pickedImages (new local photos) so the user can remove
  // an old one without being forced to re-upload every photo from scratch.
  final List<String> _existingImageUrls = [];

  bool get _isEditing => widget.editVehicleId != null;
  bool _loadingExisting = false;
  String? _loadError;

  // Tracks which user's data currently fills this form. The bottom nav
  // keeps every tab alive (see MainScaffold's IndexedStack), so this
  // screen's state is never disposed when the app navigates away from it —
  // only when the logged-in user actually changes do we need to wipe
  // whatever was typed, otherwise the next person to open Sell (e.g. after
  // logging out and a different account logging back in) would see the
  // previous user's half-filled form. Not relevant in edit mode, since that
  // screen is a fresh page each time it's pushed.
  String? _formOwnerUserId;

  static const _categories = ['Cars', 'Bikes', 'Scooters'];
  static const _fuelTypes = ['Petrol', 'Diesel', 'Electric', 'CNG'];
  static const _transmissions = ['Manual', 'Automatic'];
  static const _ownersOptions = ['1 Owner', '2 Owners', '3 Owners', '4+ Owners'];
  static const _conditionOptions = ['Excellent', 'Good', 'Fair', 'Needs Repair'];
  static const _insuranceOptions = ['Valid', 'Expired', 'Not Available'];
  static const _rcStatusOptions = ['Clear', 'Pending Transfer', 'Disputed'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // Defer until after the first frame so `ref`/context are safe to use.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _originalPriceCtrl.dispose();
    _yearCtrl.dispose();
    _kmCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadForEdit() async {
    setState(() {
      _loadingExisting = true;
      _loadError = null;
    });
    final vehicle = await VehicleService.instance.getById(widget.editVehicleId!);
    if (!mounted) return;

    final currentUserId = ref.read(authProvider).user?.id;
    if (vehicle == null) {
      setState(() {
        _loadingExisting = false;
        _loadError = 'Could not load this listing.';
      });
      return;
    }
    // Defence in depth — the backend also rejects this, but don't even let
    // someone see another seller's data prefilled into an editable form.
    if (currentUserId == null || vehicle.sellerId != currentUserId) {
      setState(() {
        _loadingExisting = false;
        _loadError = 'You can only edit your own listings.';
      });
      return;
    }

    _nameCtrl.text = vehicle.name;
    _priceCtrl.text = vehicle.priceAmount > 0 ? vehicle.priceAmount.toString() : '';
    // Uses the raw originalPriceAmount (int), not the formatted "originalPrice"
    // string ("₹13.4L") — parsing that back into an exact number would be
    // lossy and could silently change the value on the next save.
    _originalPriceCtrl.text = (vehicle.originalPriceAmount != null && vehicle.originalPriceAmount! > 0)
        ? vehicle.originalPriceAmount.toString()
        : '';
    _yearCtrl.text = vehicle.year;
    _kmCtrl.text = vehicle.kmDriven.replaceAll(RegExp(r'[^0-9]'), '');
    _locationCtrl.text = vehicle.location;
    _phoneCtrl.text = vehicle.sellerPhone;
    _descCtrl.text = vehicle.description;

    // FIX: this used to re-parse the human-readable `insurance` string
    // ("Valid till 12 Dec 2027") back into a DateTime, which is exactly
    // the kind of lossy round-trip the comment above it warned about for
    // originalPrice — a display string was never meant to be parsed back.
    // The backend now sends the actual date separately
    // (vehicle.insuranceValidTill, a real DateTime — see
    // VehicleModel/vehicles.js), so this just reads that directly. The
    // string-parsing fallback stays only for a listing created before
    // this field existed, where insuranceValidTill is null but the old
    // display string might still carry a real date worth recovering.
    String insuranceStatus = 'Valid';
    DateTime? insuranceExpiry = vehicle.insuranceValidTill;
    if (insuranceExpiry != null) {
      insuranceStatus = 'Valid';
    } else {
      final insurance = vehicle.insurance;
      if (insurance.startsWith('Valid till ')) {
        insuranceStatus = 'Valid';
        try {
          insuranceExpiry = DateFormat('d MMM yyyy').parse(insurance.substring('Valid till '.length));
        } catch (_) {
          insuranceExpiry = null;
        }
      } else if (_insuranceOptions.contains(insurance)) {
        insuranceStatus = insurance;
      }
    }

    setState(() {
      _category = _categories.contains(vehicle.category) ? vehicle.category : _category;
      _fuelType = _fuelTypes.contains(vehicle.fuelType) ? vehicle.fuelType : _fuelType;
      _transmission =
          _transmissions.contains(vehicle.transmission) ? vehicle.transmission : _transmission;
      _owners = _ownersOptions.contains(vehicle.owners) ? vehicle.owners : _owners;
      _condition = _conditionOptions.contains(vehicle.condition) ? vehicle.condition : _condition;
      _rcStatus = _rcStatusOptions.contains(vehicle.rcStatus) ? vehicle.rcStatus : _rcStatus;
      _insuranceStatus = insuranceStatus;
      _insuranceExpiry = insuranceExpiry;
      _existingImageUrls
        ..clear()
        ..addAll(vehicle.images.where((u) => u.startsWith('http://') || u.startsWith('https://')));
      _loadingExisting = false;
    });
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 80, limit: 8);
    if (files.isEmpty) return;
    setState(() => _pickedImages.addAll(files.map((f) => File(f.path))));
  }

  Future<void> _pickInsuranceExpiry() async {
    final now = DateTime.now();
    // FIX: firstDate used to be `DateTime(now.year - 5)` — five years in
    // the PAST — which is why any earlier date this month, or any date
    // at all going back years, was selectable for something that's
    // supposed to be an EXPIRY date. An insurance policy that already
    // expired yesterday isn't "valid" (that's what the "Expired" option
    // in the dropdown above is for); a date picked here has to be today
    // or later, or it doesn't describe a still-valid policy at all.
    // today (not `now`, which carries the current time-of-day) is used
    // as firstDate specifically so TODAY itself stays selectable — a
    // policy that expires later today is still valid right now.
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: (_insuranceExpiry != null && !_insuranceExpiry!.isBefore(today))
          ? _insuranceExpiry
          : today,
      firstDate: today,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _insuranceExpiry = picked);
  }

  /// Builds the single descriptive string stored in the backend's
  /// `insurance` field, e.g. "Valid till 12 Dec 2027", "Expired", or
  /// "Not Available".
  String _composeInsurance() {
    if (_insuranceStatus == 'Valid' && _insuranceExpiry != null) {
      return 'Valid till ${DateFormat('d MMM yyyy').format(_insuranceExpiry!)}';
    }
    return _insuranceStatus;
  }

  /// Wipes every field back to its default. Only used in create mode: after
  /// a successful submit, and whenever the logged-in user changes.
  void _resetForm() {
    _nameCtrl.clear();
    _priceCtrl.clear();
    _originalPriceCtrl.clear();
    _yearCtrl.clear();
    _kmCtrl.clear();
    _locationCtrl.clear();
    _phoneCtrl.clear();
    _descCtrl.clear();
    _formKey.currentState?.reset();
    setState(() {
      _pickedImages.clear();
      _category = 'Cars';
      _fuelType = 'Petrol';
      _transmission = 'Manual';
      _owners = '1 Owner';
      _condition = 'Good';
      _insuranceStatus = 'Valid';
      _insuranceExpiry = null;
      _rcStatus = 'Clear';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one photo of the vehicle')),
      );
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      if (mounted) context.push('/login');
      return;
    }

    setState(() => _submitting = true);
    try {
      var imageUrls = List<String>.of(_existingImageUrls);
      if (_pickedImages.isNotEmpty) {
        setState(() => _uploadingPhotos = true);
        final uploaded = await VehicleService.instance.uploadImages(_pickedImages);
        imageUrls = [...imageUrls, ...uploaded];
        setState(() => _uploadingPhotos = false);
      }

      final originalPriceText = _originalPriceCtrl.text.trim();

      final payload = {
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'price': int.parse(_priceCtrl.text.trim()),
        // Only include a real number, or explicit null to clear a
        // previously-set original price — never an empty string, which the
        // backend's isInt() validator would reject.
        'originalPrice': originalPriceText.isEmpty ? null : int.parse(originalPriceText),
        'year': _yearCtrl.text.trim(),
        'kmDriven': '${_kmCtrl.text.trim()} km',
        'location': _locationCtrl.text.trim(),
        'sellerPhone': _phoneCtrl.text.trim(),
        'fuelType': _fuelType,
        'transmission': _transmission,
        'owners': _owners,
        'condition': _condition,
        'insurance': _composeInsurance(),
        // The real date behind the display string above — null clears it
        // (e.g. insurance status was changed away from "Valid"). This is
        // what the backend's automatic expiry sweep actually checks
        // against; the display string alone is never parsed for that.
        'insuranceValidTill':
            (_insuranceStatus == 'Valid' && _insuranceExpiry != null) ? _insuranceExpiry!.toIso8601String() : null,
        'rcStatus': _rcStatus,
        'description': _descCtrl.text.trim(),
        'images': imageUrls,
      };

      // Captured rather than discarded: the response tells us whether
      // this listing is attributed to a dealer (savedVehicle.dealerId),
      // which is what's needed right below to refresh that dealer's own
      // profile too — the seller's own account isn't enough to know this
      // reliably from here (an edit doesn't change dealer affiliation,
      // but reading it straight off what the server actually stored is
      // more direct than re-deriving it from auth state).
      final savedVehicle = _isEditing
          ? await VehicleService.instance.updateListing(widget.editVehicleId!, payload)
          : await VehicleService.instance.createListing(payload);

      // The listing is now live on the server — refresh every screen that
      // shows vehicle data so this change shows up immediately without
      // needing an app restart: Home's general + featured feeds, Search's
      // results, this seller's own "My Listings" tab in Profile, and (when
      // editing) the vehicle's own details page.
      ref.invalidate(vehiclesProvider);
      ref.invalidate(featuredVehiclesProvider);
      ref.invalidate(searchResultsProvider);
      ref.invalidate(myListingsProvider);
      if (_isEditing) ref.invalidate(vehicleDetailProvider(widget.editVehicleId!));
      // FIX: this listing being new/changed used to never touch the
      // dealer profile at all — a dealer-linked seller adding or editing
      // a listing left that dealer's own profile page (and its "N
      // vehicles" badge on Home's "Popular Dealers") showing whatever was
      // cached from before this save, until the app was fully restarted.
      if (savedVehicle.dealerId.isNotEmpty) {
        ref.invalidate(dealerDetailProvider(savedVehicle.dealerId));
        ref.invalidate(dealersProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Listing updated.' : 'Listing published! It is live now.'),
            backgroundColor: AppColors.success,
          ),
        );
        if (_isEditing) {
          context.pop();
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
        _submitting = false;
        _uploadingPhotos = false;
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (!_isEditing) {
      // Detect a change of logged-in user (including "someone logged out
      // and someone else logged in") and clear any leftover text from the
      // previous person. ref.listen runs after the frame builds, so calling
      // setState indirectly via _resetForm here is safe.
      ref.listen(authProvider, (previous, next) {
        final newUserId = next.user?.id;
        if (_formOwnerUserId != null && _formOwnerUserId != newUserId) {
          _resetForm();
        }
        _formOwnerUserId = newUserId;
      });
      _formOwnerUserId ??= auth.user?.id;
    }

    if (!auth.isAuthenticated) {
      final body = SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text('Sign in to list your vehicle'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
      return _isEditing ? Scaffold(appBar: AppBar(title: const Text('Edit Vehicle')), body: body) : body;
    }

    if (_isEditing && _loadingExisting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Vehicle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isEditing && _loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Vehicle')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final form = SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (!_isEditing) ...[
              const Text(
                'Sell Your Vehicle',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in the details below and add real photos — your listing goes live immediately.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
            ],
            _photoPlaceholder(),
            const SizedBox(height: 20),
            _field(_nameCtrl, 'Vehicle name', 'e.g. Maruti Swift VXI'),
            const SizedBox(height: 14),
            _dropdown('Category', _category, _categories, (v) => setState(() => _category = v!)),
            const SizedBox(height: 14),
            _field(_priceCtrl, 'Price (₹)', '480000',
                keyboard: TextInputType.number, validator: _validatePrice),
            const SizedBox(height: 14),
            _field(
              _originalPriceCtrl,
              'Original price (₹) — optional',
              '550000',
              keyboard: TextInputType.number,
              validator: _validateOriginalPrice,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Only fill this in if the vehicle genuinely used to be priced higher — '
                'this is what shows the "X% off" badge on the listing. Leave blank for no badge.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _field(_yearCtrl, 'Year', '2021', keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(_kmCtrl, 'KM driven', '28000', keyboard: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 14),
            _dropdown('Fuel type', _fuelType, _fuelTypes, (v) => setState(() => _fuelType = v!)),
            const SizedBox(height: 14),
            _dropdown('Transmission', _transmission, _transmissions,
                (v) => setState(() => _transmission = v!)),
            const SizedBox(height: 14),
            _field(_locationCtrl, 'Location', 'Banjara Hills, Hyderabad'),
            const SizedBox(height: 14),
            _field(_phoneCtrl, 'Contact phone', '+91 98765 43210', keyboard: TextInputType.phone),
            const SizedBox(height: 14),
            const Text(
              'Vehicle history',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _dropdown('Owners', _owners, _ownersOptions, (v) => setState(() => _owners = v!)),
            const SizedBox(height: 14),
            _dropdown('Condition', _condition, _conditionOptions,
                (v) => setState(() => _condition = v!)),
            const SizedBox(height: 14),
            _dropdown('RC status', _rcStatus, _rcStatusOptions,
                (v) => setState(() => _rcStatus = v!)),
            const SizedBox(height: 14),
            _dropdown('Insurance', _insuranceStatus, _insuranceOptions, (v) {
              setState(() {
                _insuranceStatus = v!;
                if (_insuranceStatus != 'Valid') _insuranceExpiry = null;
              });
            }),
            if (_insuranceStatus == 'Valid') ...[
              const SizedBox(height: 14),
              _insuranceExpiryPicker(),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  "If this date passes while the vehicle's still listed and unsold, "
                  "the listing is automatically taken down and you'll be notified.",
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _field(_descCtrl, 'Description', 'Describe condition, features...', maxLines: 4),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(_uploadingPhotos ? 'Uploading photos...' : 'Publishing...'),
                      ],
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Submit Listing'),
            ),
          ],
        ),
      ),
    );

    return _isEditing ? Scaffold(appBar: AppBar(title: const Text('Edit Vehicle')), body: form) : form;
  }

  Widget _insuranceExpiryPicker() {
    final label = _insuranceExpiry == null
        ? 'Insurance valid till (tap to pick a date)'
        : 'Insurance valid till ${DateFormat('d MMM yyyy').format(_insuranceExpiry!)}';
    return InkWell(
      onTap: _pickInsuranceExpiry,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _insuranceExpiry == null ? AppColors.textSecondary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingImageUrls.map((url) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AppImage(source: url, width: 100, height: 100),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _existingImageUrls.remove(url)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              ..._pickedImages.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(f, width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _pickedImages.remove(f)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
                      SizedBox(height: 6),
                      Text('Add photo', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (_pickedImages.isEmpty && _existingImageUrls.isEmpty)
              ? 'Add at least one real photo of the vehicle'
              : '${_pickedImages.length + _existingImageUrls.length} photo(s) selected',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // The backend requires an integer price of at least ₹1000 (POST /vehicles
  // validates `price` with isInt({min: 1000})). Checking it here — with a
  // clear, specific message — means a bad value never reaches the server
  // at all instead of coming back as a hard-to-read "Request failed (400)".
  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Enter a valid whole number';
    if (n < 1000) return 'Price must be at least ₹1000';
    return null;
  }

  // Optional field — empty is valid (means "no discount badge"). But if a
  // value IS entered, it must satisfy the same rule the backend enforces
  // (isInt >= 1000, and strictly greater than the current Price), so a bad
  // value is caught here instead of coming back as a 400 after upload.
  String? _validateOriginalPrice(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null) return 'Enter a valid whole number';
    if (n < 1000) return 'Must be at least ₹1000';
    final price = int.tryParse(_priceCtrl.text.trim());
    if (price != null && n <= price) {
      return 'Must be higher than the current price to show a discount';
    }
    return null;
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator ?? (v) => v != null && v.trim().isNotEmpty ? null : 'Required',
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}